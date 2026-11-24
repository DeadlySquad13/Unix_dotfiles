#!/usr/bin/env bash
# Manilov netns datapath harness.
#
# Runs each case inside a fresh user+network namespace with the real `ip` and
# `nft` from iproute2/nftables. Nothing outside the namespace is touched; the
# applier's filesystem writes are redirected with `--root` into a temp dir.
#
# Usage (inside the dev shell):
#   unshare -Urn true && nix develop .#manilov-netns --command bash tests/manilov/netns/run.sh
#
# Exits 77 when user+net namespaces are unavailable.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "$here/../../.." && pwd)
fixtures="$repo/tests/fixtures/manilov"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

say() {
  printf '\n=== %s ===\n' "$*"
}

resolve_bin() {
  if [[ -n "${MANILOV_NETWORK_BIN:-}" && -x "${MANILOV_NETWORK_BIN:-}" ]]; then
    return 0
  fi
  if command -v manilov-network >/dev/null 2>&1; then
    MANILOV_NETWORK_BIN=$(command -v manilov-network)
    export MANILOV_NETWORK_BIN
    return 0
  fi
  if command -v nix >/dev/null 2>&1; then
    MANILOV_NETWORK_BIN="$(nix build --no-link --print-out-paths "$repo#manilov-network" | tail -n 1)/bin/manilov-network"
    export MANILOV_NETWORK_BIN
    return 0
  fi
  fail "manilov-network not found; enter \`nix develop .#manilov-netns\` or set MANILOV_NETWORK_BIN"
}

# ---------------------------------------------------------------------------
# Outer driver: one fresh user+net namespace per case.
# ---------------------------------------------------------------------------
if [[ -z "${MANILOV_NETNS_CASE:-}" ]]; then
  if ! unshare -Urn true 2>/dev/null; then
    printf 'SKIP(77): `unshare -Urn true` failed; the netns harness needs unprivileged user+net namespaces.\n' >&2
    exit 77
  fi
  resolve_bin
  cases=(
    proxyarp-apply
    bridge-apply
    health-fail
    deadman-300
    deadman-after-confirm
    deadman-before-enslave
    host-permit
    rollback
  )
  for case_name in "${cases[@]}"; do
    say "case: $case_name"
    set +e
    MANILOV_NETNS_CASE="$case_name" unshare -Urn --map-root-user --fork bash "$0"
    rc=$?
    set -e
    if [ "$rc" -ne 0 ]; then
      printf 'FAIL: case %s exited %s\n' "$case_name" "$rc" >&2
      exit "$rc"
    fi
    printf 'PASS: %s\n' "$case_name"
  done
  printf '\nall netns cases passed\n'
  exit 0
fi

# ---------------------------------------------------------------------------
# Per-case body (already inside the fresh user+net namespace).
# ---------------------------------------------------------------------------
: "${MANILOV_NETWORK_BIN:?MANILOV_NETWORK_BIN must be exported by the driver}"
bin="$MANILOV_NETWORK_BIN"
export MANILOV_DEADMAN_BACKEND=process

work=$(mktemp -d)
SSHD_PID=""
cleanup() {
  if [[ -n "$SSHD_PID" ]]; then
    kill "$SSHD_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$work"
}
trap cleanup EXIT

mkdir -p "$work/etc/manilov"
cp "$fixtures/salt.json" "$work/etc/manilov/salt.json"
cp "$fixtures/terra.json" "$work/etc/manilov/terra.json"

marker_path() {
  printf '/etc/manilov/%s' "$1"
}

apply_marker() {
  "$bin" apply --root "$work" --marker "$(marker_path "$1")"
}

confirm_marker() {
  "$bin" confirm --root "$work" --marker "$(marker_path "$1")"
}

state_file="$work/var/lib/manilov-network/state.json"

install_host_permit() {
  # @terra's real shape: the IPv4 `filter` table has a `FORWARD` base chain
  # with policy drop and a jump to MANILOV_FORWARD.
  nft add table ip filter
  nft add chain ip filter FORWARD '{ type filter hook forward priority 0; policy drop; }'
  nft add chain ip filter MANILOV_FORWARD
  nft add rule ip filter FORWARD jump MANILOV_FORWARD
}

install_host_permit_inet() {
  # Portability case: same permit shape in family `inet`.
  nft add table inet filter
  nft add chain inet filter FORWARD '{ type filter hook forward priority 0; policy drop; }'
  nft add chain inet filter MANILOV_FORWARD
  nft add rule inet filter FORWARD jump MANILOV_FORWARD
}

install_host_permit_no_drop() {
  # Jump present, but the FORWARD base chain accepts: not a permit.
  nft add table ip filter
  nft add chain ip filter FORWARD '{ type filter hook forward priority 0; policy accept; }'
  nft add chain ip filter MANILOV_FORWARD
  nft add rule ip filter FORWARD jump MANILOV_FORWARD
}

install_host_permit_dual_partial() {
  # Both `ip filter` and `inet filter` have a policy-drop FORWARD chain, but
  # only the `ip` one jumps: the `inet` chain still drops, so no permit.
  nft add table ip filter
  nft add chain ip filter FORWARD '{ type filter hook forward priority 0; policy drop; }'
  nft add chain ip filter MANILOV_FORWARD
  nft add rule ip filter FORWARD jump MANILOV_FORWARD
  nft add table inet filter
  nft add chain inet filter FORWARD '{ type filter hook forward priority 0; policy drop; }'
  nft add chain inet filter MANILOV_FORWARD
}

install_host_permit_dual_ok() {
  # Same dual shape, but every drop-policy FORWARD chain jumps.
  install_host_permit_dual_partial
  nft add rule inet filter FORWARD jump MANILOV_FORWARD
}

assert_host_permit_json() {
  # Mirrors the shape in tests/fixtures/manilov/nft-host-permit.json: the
  # jump must live in every `FORWARD` base chain whose policy is drop.
  nft -j list ruleset | jq -e '
    . as $root
    | [ $root.nftables[]? | objects | select(has("chain")) | .chain
        | select(.name == "FORWARD" and (.policy // "") == "drop")
        | {family, table} ] as $drop_tables
    | ($drop_tables | length) > 0
      and all($drop_tables[];
          . as $t
          | [ $root.nftables[]? | objects | select(has("rule")) | .rule
              | select(.family == $t.family and .table == $t.table and .chain == "FORWARD")
              | .expr[]? | objects | select(has("jump")) | .jump.target ]
          | index("MANILOV_FORWARD") != null)
  ' >/dev/null
}

make_bridge_uplink() {
  ip link add eth-test0 type veth peer name uplink-peer
  ip link set uplink-peer up
  ip link set eth-test0 address 02:00:00:00:00:02
  ip link set eth-test0 up
}

make_proxyarp_uplink() {
  ip link add wlan-test0 type dummy
  ip link set wlan-test0 address 02:00:00:00:00:01
  ip link set wlan-test0 up
}

make_proxyarp_tap() {
  # `ip link add ... type tap` (the applier's rtnl kind) is not exposed by this
  # kernel. Create the marker's tap through the tun ioctl instead; the
  # applier's own existence check then skips link.add.
  if ! ip tuntap add dev tap-test0 mode tap 2>/dev/null; then
    fail "cannot create tap-test0 (tun driver unavailable)"
  fi
  ip link set tap-test0 up
}

start_sshd() {
  socat TCP-LISTEN:22,fork,reuseaddr SYSTEM:'true' >/dev/null 2>&1 &
  SSHD_PID=$!
  for _ in $(seq 1 50); do
    if ss -ltn | grep -Eq '[:.]22[[:space:]]'; then
      return 0
    fi
    sleep 0.1
  done
  fail "sshd stand-in did not listen on port 22"
}

assert_addr() {
  local dev="$1"
  local addr="$2"
  ip -j addr show dev "$dev" | jq -e --arg a "$addr" \
    '[.[].addr_info[]?.local] | index($a) != null' >/dev/null
}

assert_route() {
  local dev="$1"
  local gw="$2"
  ip -j route show default | jq -e --arg d "$dev" --arg g "$gw" \
    'any(.dst == "default" and .dev == $d and .gateway == $g)' >/dev/null
}

assert_image_tables() {
  nft list tables | grep -q 'table bridge manilov_vm'
  nft list tables | grep -q 'table inet manilov_vm'
}

assert_link_absent() {
  local dev="$1"
  if ip link show dev "$dev" >/dev/null 2>&1; then
    fail "expected $dev to be absent"
  fi
}

case_proxyarp_apply() {
  make_proxyarp_uplink
  make_proxyarp_tap
  install_host_permit
  apply_marker salt.json

  ip link show dev tap-test0 >/dev/null
  assert_addr tap-test0 192.0.2.10
  assert_image_tables

  local out
  out=$(apply_marker salt.json 2>&1)
  printf '%s' "$out" | grep -q 'apply no-op' || fail "second proxyarp apply was not a no-op"
}

case_bridge_apply() {
  make_bridge_uplink
  install_host_permit
  start_sshd
  apply_marker terra.json

  ip link show dev br0 >/dev/null
  assert_addr br0 198.51.100.10
  assert_route br0 198.51.100.1
  assert_image_tables

  local out
  out=$(apply_marker terra.json 2>&1)
  printf '%s' "$out" | grep -q 'apply no-op' || fail "second bridge apply was not a no-op"

  # Complete the two-phase apply so the dead-man process is cancelled.
  confirm_marker terra.json >/dev/null
}

case_health_fail() {
  make_bridge_uplink
  install_host_permit
  # No sshd stand-in: the post-apply probe must fail and roll back.

  set +e
  apply_marker terra.json >/dev/null 2>&1
  local rc=$?
  set -e
  [ "$rc" -eq 10 ] || fail "health-fail: expected apply exit 10, got $rc"

  jq -e '.phase == "rolled-back" and .handoff.reason == "health"' "$state_file" >/dev/null
  assert_link_absent br0
}

case_deadman_300() {
  make_bridge_uplink
  install_host_permit
  start_sshd
  apply_marker terra.json

  # Do not sleep 300 s: drive the unconfirmed dead-man guard with a deadline
  # that is already in the past.
  "$bin" rollback --reason deadman --if-unconfirmed \
    --deadline "$(( $(date +%s) - 1 ))" \
    --root "$work" --marker "$(marker_path terra.json)"

  jq -e '.phase == "rolled-back" and .handoff.reason == "deadman"' "$state_file" >/dev/null
  assert_link_absent br0
}

case_deadman_after_confirm() {
  make_bridge_uplink
  install_host_permit
  start_sshd
  apply_marker terra.json
  confirm_marker terra.json >/dev/null

  set +e
  "$bin" rollback --reason deadman --if-unconfirmed \
    --deadline "$(( $(date +%s) - 1 ))" \
    --root "$work" --marker "$(marker_path terra.json)" >/dev/null 2>&1
  local rc=$?
  set -e
  [ "$rc" -eq 0 ] || fail "deadman-after-confirm: expected exit 0, got $rc"

  ip link show dev br0 >/dev/null
  jq -e '.phase == "applied"' "$state_file" >/dev/null
}

case_deadman_before_enslave() {
  # Enslaving the uplink to br0 is the first bridge op that can break
  # management, so the dead-man must already exist when `link set <uplink>
  # master br0` runs. A wrapper around the real `ip` records call order and
  # checks the transient dead-man at that exact instant, then fails the
  # enslave so the applier exits after arming (and before L3 moves).
  make_bridge_uplink
  install_host_permit

  local fakebin="$work/fake-ip"
  local log="$work/ip-calls.log"
  local okfile="$work/deadman-before-enslave.ok"
  local state="$work/var/lib/manilov-network/state.json"
  local rtdir="$work/run/manilov-network"
  local real_ip
  real_ip=$(command -v ip)
  mkdir -p "$fakebin" "$work/bin"

  cat > "$fakebin/ip" <<'FAKE_IP'
#!/usr/bin/env bash
set -u
printf 'ip %s\n' "$*" >> "$MANILOV_IP_LOG"
if [[ "${1:-}" == "link" && "${2:-}" == "set" && "${3:-}" == "dev" && "${5:-}" == "master" ]]; then
  armed_at=$(jq -r '.deadmanArmedAt // empty' "$MANILOV_STATE_FILE" 2>/dev/null || true)
  if [[ -z "$armed_at" ]]; then
    printf 'deadman-before-enslave: deadmanArmedAt is unset when link.master runs\n' >&2
    exit 90
  fi
  if [[ ! -f "$MANILOV_RUNTIME_DIR/deadman.pid" ]]; then
    printf 'deadman-before-enslave: deadman pid file is missing when link.master runs\n' >&2
    exit 91
  fi
  pid=$(cat "$MANILOV_RUNTIME_DIR/deadman.pid")
  if ! kill -0 "$pid" 2>/dev/null; then
    printf 'deadman-before-enslave: deadman process %s is not alive when link.master runs\n' "$pid" >&2
    exit 92
  fi
  printf 'armedAt=%s pid=%s\n' "$armed_at" "$pid" > "$MANILOV_ENSLAVE_OK"
  # Prove the arm happened before the disruptive op by failing it; the
  # applier turns this into exit 9.
  exit 1
fi
exec "$MANILOV_REAL_IP" "$@"
FAKE_IP
  chmod +x "$fakebin/ip"

  # writeShellApplication puts its runtimeInputs ahead of $PATH, so patch a
  # copy of the applier to put the fake `ip` first (same technique as
  # checks/manilov-network-pure).
  local runner="$work/bin/manilov-network"
  sed "s|^export PATH=\"|export PATH=\"$fakebin:|" "$bin" > "$runner"
  chmod +x "$runner"

  set +e
  MANILOV_IP_LOG="$log" \
    MANILOV_STATE_FILE="$state" \
    MANILOV_RUNTIME_DIR="$rtdir" \
    MANILOV_ENSLAVE_OK="$okfile" \
    MANILOV_REAL_IP="$real_ip" \
    "$runner" apply --root "$work" --marker "$(marker_path terra.json)" >/dev/null 2>&1
  local rc=$?
  set -e

  [ -f "$okfile" ] || fail "deadman-before-enslave: link.master ran before the dead-man was armed (apply exit $rc)"
  grep -Eq '^ip link set dev .* master ' "$log" || fail "deadman-before-enslave: no link.master call was recorded"
  jq -e '.deadmanArmedAt != null' "$state" >/dev/null \
    || fail "deadman-before-enslave: state.deadmanArmedAt is not set"
  [ "$rc" -eq 9 ] || fail "deadman-before-enslave: expected apply exit 9 after the forced enslave failure, got $rc"

  if [[ -f "$rtdir/deadman.pid" ]]; then
    local pid
    pid=$(cat "$rtdir/deadman.pid")
    kill -- "-$pid" >/dev/null 2>&1 || kill "$pid" >/dev/null 2>&1 || true
  fi
}

expect_check() {
  local want="$1"
  local label="$2"
  set +e
  "$bin" check --root "$work" --marker "$(marker_path salt.json)" >/dev/null 2>&1
  local rc=$?
  set -e
  [ "$rc" -eq "$want" ] || fail "host-permit($label): expected exit $want, got $rc"
}

case_host_permit() {
  make_proxyarp_uplink

  # Without a permit at all: fail closed.
  expect_check 7 "none"

  # The real @terra shape: ip filter, FORWARD policy drop.
  install_host_permit
  expect_check 0 "ip"
  assert_host_permit_json
  nft delete table ip filter

  # Portability: the same shape in family inet.
  install_host_permit_inet
  expect_check 0 "inet"
  nft delete table inet filter

  # Jump present but FORWARD accepts: not a permit.
  install_host_permit_no_drop
  expect_check 7 "no-drop"
  nft delete table ip filter

  # Both families drop; only `ip` jumps: the `inet` drop still bites.
  install_host_permit_dual_partial
  expect_check 7 "dual-partial"
  nft delete table ip filter
  nft delete table inet filter

  # Both families drop and both jump: a permit.
  install_host_permit_dual_ok
  expect_check 0 "dual-ok"
  assert_host_permit_json
  nft delete table ip filter
  nft delete table inet filter
}

case_rollback() {
  make_bridge_uplink
  install_host_permit
  start_sshd
  apply_marker terra.json

  # Host-owned state that rollback must not touch.
  nft add table inet host_keep
  nft add chain inet host_keep keep
  nft add rule ip filter FORWARD iifname "lo" accept
  local before
  before=$(nft list table ip filter)

  "$bin" rollback --reason manual --root "$work" --marker "$(marker_path terra.json)"

  local after
  after=$(nft list table ip filter)
  [ "$before" = "$after" ] || fail "rollback changed the host ip filter table"
  nft list table inet host_keep >/dev/null

  assert_link_absent br0
  if nft list tables | grep -q 'table bridge manilov_vm'; then
    fail "rollback left table bridge manilov_vm"
  fi
  if nft list tables | grep -q 'table inet manilov_vm'; then
    fail "rollback left table inet manilov_vm"
  fi
  ip link show dev eth-test0 >/dev/null
}

case "$MANILOV_NETNS_CASE" in
  proxyarp-apply) case_proxyarp_apply ;;
  bridge-apply) case_bridge_apply ;;
  health-fail) case_health_fail ;;
  deadman-300) case_deadman_300 ;;
  deadman-after-confirm) case_deadman_after_confirm ;;
  deadman-before-enslave) case_deadman_before_enslave ;;
  host-permit) case_host_permit ;;
  rollback) case_rollback ;;
  *) fail "unknown netns case: $MANILOV_NETNS_CASE" ;;
esac
