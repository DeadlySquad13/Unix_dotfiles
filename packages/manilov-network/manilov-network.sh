# shellcheck shell=bash
# shellcheck disable=SC2016
# Manilov network applier.
#
# This file is embedded by packages/manilov-network/default.nix through
# writeShellApplication. `MANILOV_PROFILES_JSON` is injected immediately before
# this text by that derivation.
#
# Design notes:
# - All state writes are temp-file + mv (write_atomic).
# - `check`/`status`/`host-permit` never write; only mutation verbs take the
#   owner lock.
# - The nft rules emitted here are drop-only. The applier never writes the host
#   `filter` table and never flushes the ruleset.

readonly MANILOV_VERSION="1.0.0"
readonly MANILOV_IMAGE_DEFAULT="nikolaigogol"
readonly MARKER_SCHEMA="manilov.network.marker/v1"
readonly MAX_CONFIRM_DEADLINE_DEFAULT=900

VERB=""
MARKER_PATH="${MANILOV_MARKER_PATH:-/etc/manilov/marker.json}"
STATE_DIR_OPT="${MANILOV_STATE_DIR:-/var/lib/manilov-network}"
RUNTIME_DIR_OPT="${MANILOV_RUNTIME_DIR:-/run/manilov-network}"
ROOT=""
NETLINK_FIXTURE=""
PLAN_MODE=0
JSON_OUT=0
REASON=""
TO_VALUE=""
FORCE=0
IF_UNCONFIRMED=0
DEADLINE=""

MANILOV_IMAGE_ID="${MANILOV_IMAGE_ID:-$MANILOV_IMAGE_DEFAULT}"

MARKER_JSON=""
PARAMS_JSON=""
PROFILE=""
MARKER_ROLE=""
MARKER_OWNER_KIND=""
MARKER_OWNER_ID=""
MARKER_SELECTOR_DIGEST=""
STATE_JSON=""
PLAN_JSON=""
plan_digest=""
params_digest=""
HEALTH_CHECKS_JSON="[]"
HEALTH_OVERALL="pass"
DEADMAN_UNIT=""

usage() {
  cat <<'EOF'
Usage: manilov-network <verb> [options]

Verbs:
  check         Read-only marker, digest, owner, uplink and host-permit check.
  apply         Apply the marker-selected profile (owner role only).
  confirm       Confirm an unconfirmed bridge apply (operator only).
  extend        Extend the unconfirmed confirm deadline.
  status        Read-only phase/health status.
  rollback      Remove image-owned datapath objects.
  watchdog      Read-only health check plus automatic rollback on hard failure.
  host-permit   Read-only check for host filter FORWARD -> MANILOV_FORWARD.

Options:
  --marker PATH            Marker JSON (default /etc/manilov/marker.json).
  --state-dir PATH         Durable state directory (default /var/lib/manilov-network).
  --root PATH              Prefix /run, /var/lib and /etc paths (test sandbox).
  --netlink-fixture PATH   Read interface/address/route data from JSON.
  --plan                   Print the resolved profile plan and exit.
  --json                   Emit machine-readable JSON where supported.
  --reason VALUE           rollback reason: health|deadman|manual|auto.
  --to N                   extend: new deadline in seconds from appliedAt.
  --force                  confirm a degraded datapath.
  --if-unconfirmed         rollback: only act while phase=unconfirmed.
  --deadline EPOCH         rollback: only act at/after this epoch.
  --version                Print version and exit.
  --help                   Print this help and exit.

Exit codes:
  0 ok/guarded no-op    2 usage                 3 marker/digest
  4 identity            5 uplink                6 owner conflict
  7 host-permit-missing 8 schema/params         9 apply
  10 rollback           11 phase/profile/confirm refusal
  12 read-only
EOF
}

die() {
  local code="$1"
  shift
  printf 'manilov-network: %s\n' "$*" >&2
  exit "$code"
}

info() {
  printf 'manilov-network: %s\n' "$*" >&2
}

is_uint() {
  local value="$1"
  [[ "$value" =~ ^[0-9]+$ ]]
}

now_iso() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

now_epoch() {
  date +%s
}

rooted() {
  local path="$1"
  if [[ -z "$ROOT" || "$path" != /* ]]; then
    printf '%s' "$path"
    return 0
  fi
  local root_no_slash="${ROOT%/}"
  if [[ "$path" == "$root_no_slash" || "$path" == "$root_no_slash/"* ]]; then
    printf '%s' "$path"
  else
    printf '%s%s' "$root_no_slash" "$path"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --marker)
      [[ $# -ge 2 ]] || die 2 "--marker requires a value"
      MARKER_PATH="$2"
      shift 2
      ;;
    --state-dir)
      [[ $# -ge 2 ]] || die 2 "--state-dir requires a value"
      STATE_DIR_OPT="$2"
      shift 2
      ;;
    --root)
      [[ $# -ge 2 ]] || die 2 "--root requires a value"
      ROOT="$2"
      shift 2
      ;;
    --netlink-fixture)
      [[ $# -ge 2 ]] || die 2 "--netlink-fixture requires a value"
      NETLINK_FIXTURE="$2"
      shift 2
      ;;
    --plan)
      PLAN_MODE=1
      shift
      ;;
    --json)
      JSON_OUT=1
      shift
      ;;
    --reason)
      [[ $# -ge 2 ]] || die 2 "--reason requires a value"
      REASON="$2"
      shift 2
      ;;
    --to)
      [[ $# -ge 2 ]] || die 2 "--to requires a value"
      TO_VALUE="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --if-unconfirmed)
      IF_UNCONFIRMED=1
      shift
      ;;
    --deadline)
      [[ $# -ge 2 ]] || die 2 "--deadline requires a value"
      DEADLINE="$2"
      shift 2
      ;;
    --version)
      printf 'manilov-network %s (image %s)\n' "$MANILOV_VERSION" "$MANILOV_IMAGE_ID"
      exit 0
      ;;
    --help | -h)
      usage
      exit 0
      ;;
    --*)
      die 2 "unknown option: $1"
      ;;
    *)
      if [[ -n "$VERB" ]]; then
        die 2 "unexpected argument: $1"
      fi
      VERB="$1"
      shift
      ;;
  esac
done

case "$VERB" in
  check | apply | confirm | extend | status | rollback | watchdog | host-permit) ;;
  "")
    if [[ "$PLAN_MODE" -eq 0 ]]; then
      usage
      exit 2
    fi
    ;;
  *) die 2 "unknown verb: $VERB" ;;
esac

if [[ -n "$DEADLINE" ]] && ! is_uint "$DEADLINE"; then
  die 2 "--deadline expects a non-negative integer epoch"
fi

MARKER_FILE=$(rooted "$MARKER_PATH")
STATE_DIR=$(rooted "$STATE_DIR_OPT")
RUNTIME_DIR=$(rooted "$RUNTIME_DIR_OPT")
STATE_FILE="$STATE_DIR/state.json"
OWNER_FILE="$STATE_DIR/owner.json"
LOCK_FILE="$RUNTIME_DIR/owner.lock"

selector_digest() {
  local profile="$1"
  local role="$2"
  local id="$3"
  jq -jS -c -n \
    --arg schema "$MARKER_SCHEMA" \
    --arg profile "$profile" \
    --arg role "$role" \
    --arg id "$id" \
    '{schema:$schema,profile:$profile,role:$role,owner:{kind:"image",id:$id}}' \
    | sha256sum | awk '{print "sha256:" $1}'
}

load_marker() {
  [[ -f "$MARKER_FILE" ]] || die 3 "marker missing: $MARKER_FILE"
  MARKER_JSON=$(jq -c . "$MARKER_FILE" 2>/dev/null) || die 3 "marker is not valid JSON: $MARKER_FILE"

  PROFILE=$(printf '%s' "$MARKER_JSON" | jq -r '.profile // empty')
  MARKER_ROLE=$(printf '%s' "$MARKER_JSON" | jq -r '.role // empty')
  MARKER_OWNER_KIND=$(printf '%s' "$MARKER_JSON" | jq -r '.owner.kind // empty')
  MARKER_OWNER_ID=$(printf '%s' "$MARKER_JSON" | jq -r '.owner.id // empty')
  MARKER_SELECTOR_DIGEST=$(printf '%s' "$MARKER_JSON" | jq -r '.selectorDigest // empty')
  PARAMS_JSON=$(printf '%s' "$MARKER_JSON" | jq -c '.params // {}')
}

validate_marker() {
  local schema
  schema=$(printf '%s' "$MARKER_JSON" | jq -r '.schema // empty')
  [[ "$schema" == "$MARKER_SCHEMA" ]] || die 3 "marker.schema must be $MARKER_SCHEMA"
  [[ "$PROFILE" == "proxyarp" || "$PROFILE" == "bridge" ]] || die 3 "marker.profile must be proxyarp or bridge"
  [[ "$MARKER_ROLE" == "owner" || "$MARKER_ROLE" == "consumer" ]] || die 3 "marker.role must be owner or consumer"
  [[ "$MARKER_OWNER_KIND" == "image" ]] || die 4 "marker.owner.kind must be image"
  [[ -n "$MARKER_OWNER_ID" ]] || die 3 "marker.owner.id is required"
  [[ "$MARKER_SELECTOR_DIGEST" =~ ^sha256:[0-9a-f]{64}$ ]] || die 3 "marker.selectorDigest must be sha256:<64 hex>"

  local key
  for key in uplink management addressing datapath peer; do
    if ! printf '%s' "$PARAMS_JSON" | jq -e --arg k "$key" 'has($k)' >/dev/null; then
      die 3 "marker.params.$key is required"
    fi
  done

  local expected
  expected=$(selector_digest "$PROFILE" "$MARKER_ROLE" "$MARKER_OWNER_ID")

  # Consumers are read-only and are not listed in the module's owner-selector
  # set, so their digest is always verified by recomputation. Owners accept a
  # digest that is in the module-provided allowed set, or that recomputes to an
  # allowed owner selector. Without the env (e.g. `nix run`) the recomputed
  # digest is the fallback comparison.
  if [[ "$MARKER_ROLE" == "consumer" ]]; then
    [[ "$MARKER_SELECTOR_DIGEST" == "$expected" ]] || die 3 "selector digest mismatch (expected $expected)"
  elif [[ -n "${MANILOV_ALLOWED_SELECTORS:-}" ]]; then
    if ! printf '%s' "$MANILOV_ALLOWED_SELECTORS" \
      | jq -e --arg d "$MARKER_SELECTOR_DIGEST" --arg e "$expected" \
        '[.[] | .selectorDigest? // empty] | (index($d) != null) or (index($e) != null)' >/dev/null; then
      die 3 "selector digest not in the module-provided allowed set"
    fi
  elif [[ "$MARKER_SELECTOR_DIGEST" != "$expected" ]]; then
    die 3 "selector digest mismatch (expected $expected)"
  fi

  [[ "$MARKER_OWNER_ID" == "$MANILOV_IMAGE_ID" ]] || die 4 "marker.owner.id '$MARKER_OWNER_ID' does not match image '$MANILOV_IMAGE_ID'"
}

require_owner_mutation() {
  [[ "$MARKER_ROLE" == "owner" ]] || die 12 "role=consumer is read-only"
}

default_state_json() {
  jq -n -c --arg profile "${PROFILE:-proxyarp}" '{
    profile:$profile,
    phase:"idle",
    planDigest:null,
    paramsDigest:null,
    appliedAt:null,
    confirmDeadline:null,
    confirmedAt:null,
    deadmanArmedAt:null,
    deadmanUnit:null,
    deadmanCancelled:false,
    health:"unknown",
    healthChecks:[],
    extensions:[],
    handoff:null
  }'
}

load_state() {
  if [[ -f "$STATE_FILE" ]]; then
    STATE_JSON=$(jq -c . "$STATE_FILE" 2>/dev/null) || die 3 "state file is not valid JSON: $STATE_FILE"
  else
    STATE_JSON=$(default_state_json)
  fi
}

state_get() {
  printf '%s' "$STATE_JSON" | jq -r "$1"
}

write_atomic() {
  local file="$1"
  local content="$2"
  local dir
  dir=$(dirname "$file")
  mkdir -p "$dir"
  local tmp
  tmp=$(mktemp "$dir/.$(basename "$file").XXXXXX")
  printf '%s\n' "$content" > "$tmp"
  mv "$tmp" "$file"
}

write_state() {
  write_atomic "$STATE_FILE" "$STATE_JSON"
}

current_boot_id() {
  if [[ -n "${MANILOV_BOOT_ID:-}" ]]; then
    printf '%s' "$MANILOV_BOOT_ID"
    return 0
  fi
  if [[ -r /proc/sys/kernel/random/boot_id ]]; then
    tr -d '\n' < /proc/sys/kernel/random/boot_id
    return 0
  fi
  printf 'unknown-boot'
}

current_start_id() {
  if [[ -n "${MANILOV_START_ID:-}" ]]; then
    printf '%s' "$MANILOV_START_ID"
    return 0
  fi
  if [[ -r /proc/1/stat ]]; then
    awk '{print $22}' /proc/1/stat
    return 0
  fi
  printf 'unknown-start'
}

current_container() {
  if [[ -n "${MANILOV_CONTAINER_ID:-}" ]]; then
    printf '%s' "$MANILOV_CONTAINER_ID"
    return 0
  fi
  printf '%s' "${HOSTNAME:-unknown-container}"
}

write_owner() {
  local image_json="null"
  if [[ -n "${MANILOV_IMAGE_DIGEST:-}" ]]; then
    image_json=$(jq -n --arg i "$MANILOV_IMAGE_DIGEST" '$i')
  fi
  local container
  local boot
  local start
  container=$(current_container)
  boot=$(current_boot_id)
  start=$(current_start_id)
  local owner_json
  owner_json=$(jq -n -c \
    --arg id "$MARKER_OWNER_ID" \
    --argjson image "$image_json" \
    --arg container "$container" \
    --arg boot "$boot" \
    --arg start "$start" \
    --arg profile "$PROFILE" \
    '{owner:{id:$id,image:$image},container:$container,bootId:$boot,startId:$start,profile:$profile}')
  write_atomic "$OWNER_FILE" "$owner_json"
}

acquire_lock() {
  mkdir -p "$RUNTIME_DIR"
  exec 9>"$LOCK_FILE"
  if flock -n 9; then
    return 0
  fi

  local existing_id=""
  local existing_boot=""
  if [[ -f "$OWNER_FILE" ]]; then
    existing_id=$(jq -r '.owner.id // empty' "$OWNER_FILE" 2>/dev/null || true)
    existing_boot=$(jq -r '.bootId // empty' "$OWNER_FILE" 2>/dev/null || true)
  fi

  local current_boot
  current_boot=$(current_boot_id)
  if [[ "$existing_id" == "$MARKER_OWNER_ID" && -n "$existing_boot" && "$existing_boot" != "$current_boot" ]]; then
    rm -f "$LOCK_FILE"
    exec 9>"$LOCK_FILE"
    if flock -n 9; then
      return 0
    fi
  fi

  die 6 "owner lock held by ${existing_id:-an unknown owner}"
}

check_owner_conflict() {
  [[ -f "$OWNER_FILE" ]] || return 0
  local existing_id
  existing_id=$(jq -r '.owner.id // empty' "$OWNER_FILE" 2>/dev/null || true)
  if [[ -n "$existing_id" && "$existing_id" != "$MARKER_OWNER_ID" ]]; then
    die 6 "owner conflict: $OWNER_FILE belongs to '$existing_id'"
  fi
}

build_plan() {
  local ops
  if ! ops=$(jq -c --arg profile "$PROFILE" --argjson params "$PARAMS_JSON" '
    def resolve($p):
      if type == "object" then
        if (has("$param") and ((keys | length) == 1)) then
          . as $ref
          | ($p | getpath(($ref["$param"] | split(".")))) as $v
          | if $v == null then error("missing-param:" + $ref["$param"]) else $v end
        else
          with_entries(.value |= resolve($p))
        end
      elif type == "array" then
        map(resolve($p))
      else
        .
      end;
    .[$profile] | resolve($params)
  ' <<<"$MANILOV_PROFILES_JSON" 2>/dev/null); then
    die 8 "cannot resolve profile plan for ${PROFILE}"
  fi
  PLAN_JSON="$ops"
  plan_digest=$(printf '%s' "$PLAN_JSON" | jq -jS -c . | sha256sum | awk '{print "sha256:" $1}')
  params_digest=$(printf '%s' "$PARAMS_JSON" | jq -jS -c . | sha256sum | awk '{print "sha256:" $1}')
}

management_cidr() {
  local address
  local prefix
  address=$(printf '%s' "$PARAMS_JSON" | jq -r '.management.address // empty')
  prefix=$(printf '%s' "$PARAMS_JSON" | jq -r '.management.prefix // empty')
  [[ -n "$address" ]] || die 8 "marker.params.management.address is required"
  if [[ "$address" == */* ]]; then
    printf '%s' "$address"
    return 0
  fi
  if [[ -z "$prefix" ]]; then
    if [[ "$address" == *:* ]]; then
      prefix=64
    else
      prefix=24
    fi
  fi
  printf '%s/%s' "$address" "$prefix"
}

strip_prefix() {
  printf '%s' "${1%%/*}"
}

link_exists() {
  local name="$1"
  if [[ -n "$NETLINK_FIXTURE" ]]; then
    jq -e --arg n "$name" '(.links // []) | any(.ifname == $n)' "$NETLINK_FIXTURE" >/dev/null
  else
    ip -j link show dev "$name" >/dev/null 2>&1
  fi
}

link_mac() {
  local name="$1"
  if [[ -n "$NETLINK_FIXTURE" ]]; then
    jq -r --arg n "$name" '(.links // []) | map(select(.ifname == $n)) | .[0].address // empty' "$NETLINK_FIXTURE"
  else
    ip -j link show dev "$name" 2>/dev/null | jq -r '.[0].address // empty'
  fi
}

link_is_up() {
  local name="$1"
  if [[ -n "$NETLINK_FIXTURE" ]]; then
    jq -e --arg n "$name" \
      '(.links // []) | any(.ifname == $n and (((.carrier // false) == true) or ((.operstate // "") == "UP")))' \
      "$NETLINK_FIXTURE" >/dev/null
  else
    ip -j link show dev "$name" 2>/dev/null | jq -e '.[0] | ((.carrier // false) == true) or (.operstate == "UP")' >/dev/null
  fi
}

addr_present() {
  local dev="$1"
  local address="$2"
  local want
  want=$(strip_prefix "$address")
  if [[ -n "$NETLINK_FIXTURE" ]]; then
    jq -e --arg d "$dev" --arg a "$want" \
      '(.addresses // []) | any(.ifname == $d and (((.address // "") | split("/")[0]) == $a))' \
      "$NETLINK_FIXTURE" >/dev/null
  else
    ip -j addr show dev "$dev" 2>/dev/null | jq -e --arg a "$want" '[.[].addr_info[]?.local] | index($a) != null' >/dev/null
  fi
}

route_present() {
  local dev="$1"
  local gateway="$2"
  if [[ -n "$NETLINK_FIXTURE" ]]; then
    jq -e --arg d "$dev" --arg g "$gateway" \
      '(.routes // []) | any(.dst == "default" and .dev == $d and .gateway == $g)' \
      "$NETLINK_FIXTURE" >/dev/null
  else
    ip -j route show default 2>/dev/null | jq -e --arg d "$dev" --arg g "$gateway" \
      'any(.dst == "default" and .dev == $d and .gateway == $g)' >/dev/null
  fi
}

sshd_listening() {
  if [[ -n "$NETLINK_FIXTURE" ]]; then
    jq -e '.sshd == true' "$NETLINK_FIXTURE" >/dev/null
  else
    ss -ltn 2>/dev/null | grep -Eq '[:.]22[[:space:]]'
  fi
}

require_uplink() {
  local name
  name=$(printf '%s' "$PARAMS_JSON" | jq -r '.uplink.name // empty')
  [[ -n "$name" ]] || die 5 "marker.params.uplink.name is required"
  link_exists "$name" || die 5 "uplink does not exist: $name"
}

host_permit_ok() {
  local ruleset
  if ! ruleset=$(nft -j list ruleset 2>/dev/null); then
    return 1
  fi
  # Drop-chain-aware: the permit only counts when it sits in every `filter`
  # `FORWARD` chain whose base chain policy is drop (the host's IPv4 filter
  # table on @terra is family `ip`; `inet` is accepted for portability, and if
  # both exist both need the jump). No drop policy anywhere means fail closed.
  printf '%s' "$ruleset" | jq -e '
    . as $root
    | [
        $root.nftables[]? | objects | select(has("chain")) | .chain
        | select(.name == "FORWARD" and (.policy // "") == "drop")
        | select(.family == "ip" or .family == "inet")
        | {family, table}
      ] as $drop_tables
    | ($drop_tables | length) > 0
      and all($drop_tables[];
          . as $t
          | [
              $root.nftables[]? | objects | select(has("rule")) | .rule
              | select(.family == $t.family and .table == $t.table and .chain == "FORWARD")
              | .expr[]? | objects | select(has("jump")) | .jump.target
            ] | index("MANILOV_FORWARD") != null)
  ' >/dev/null
}

require_host_permit() {
  host_permit_ok || die 7 "host-permit-missing: host filter FORWARD does not jump to MANILOV_FORWARD"
}

nft_values() {
  VM_MACS=$(printf '%s' "$PARAMS_JSON" | jq -r '
    [(.peer.mac? // empty), ((.peers // [])[]? | .mac? // empty)]
    | map("\"" + . + "\"") | join(", ")')
  local addresses
  addresses=$(printf '%s' "$PARAMS_JSON" | jq -c '
    [(.peer.address? // empty), ((.peers // [])[]? | .address? // empty)]
    | map(select(length > 0))')
  VM_PREFIXES=$(printf '%s' "$addresses" | jq -r '
    map(select(test(":") | not) | if test("/") then . else . + "/32" end) | join(", ")')
  VM_PREFIX6S=$(printf '%s' "$addresses" | jq -r '
    map(select(test(":")) | if test("/") then . else . + "/128" end) | join(", ")')
}

render_nft_rules() {
  local rules
  rules=$(printf '%s' "$PLAN_JSON" | jq -r '[.[] | select(.op == "nft.load") | .rules[]] | join("\n")')
  [[ -n "$rules" ]] || die 9 "plan has no nft.load rules"
  nft_values
  [[ -n "$VM_MACS" ]] || die 8 "params.peer/peers must declare at least one MAC"

  if [[ -z "$VM_PREFIXES" ]]; then
    rules=$(printf '%s\n' "$rules" | grep -v 'VM_PREFIXES' || true)
  fi
  if [[ -z "$VM_PREFIX6S" ]]; then
    rules=$(printf '%s\n' "$rules" | grep -v 'VM_PREFIX6S' || true)
  fi

  rules=${rules//\$VM_MACS/$VM_MACS}
  rules=${rules//\$VM_PREFIXES/$VM_PREFIXES}
  rules=${rules//\$VM_PREFIX6S/$VM_PREFIX6S}
  NFT_RULES_TEXT="$rules"
}

apply_nft() {
  render_nft_rules
  local tmp
  tmp=$(mktemp "${TMPDIR:-/tmp}/manilov-network-nft.XXXXXX")
  printf '%s\n' "$NFT_RULES_TEXT" > "$tmp"
  if ! nft -c -f "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    die 8 "nft rule validation failed"
  fi
  # Only the two image-owned tables are replaced. Never flush the ruleset and
  # never touch the host `filter` table.
  nft delete table bridge manilov_vm >/dev/null 2>&1 || true
  nft delete table inet manilov_vm >/dev/null 2>&1 || true
  if ! nft -f "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    die 9 "nft apply failed"
  fi
  rm -f "$tmp"
}

execute_op() {
  local op="$1"
  local kind
  kind=$(printf '%s' "$op" | jq -r '.op')
  case "$kind" in
    assert.linkMac)
      local mac_name
      local mac_want
      local mac_have
      mac_name=$(printf '%s' "$op" | jq -r '.name')
      mac_want=$(printf '%s' "$op" | jq -r '.mac')
      mac_have=$(link_mac "$mac_name")
      [[ -n "$mac_have" ]] || die 5 "cannot read MAC for $mac_name"
      if [[ "${mac_have,,}" != "${mac_want,,}" ]]; then
        die 5 "uplink MAC mismatch on $mac_name: expected $mac_want, got $mac_have"
      fi
      ;;
    link.add)
      local add_name
      local add_type
      add_name=$(printf '%s' "$op" | jq -r '.name')
      add_type=$(printf '%s' "$op" | jq -r '.type')
      if ! link_exists "$add_name"; then
        ip link add name "$add_name" type "$add_type" >/dev/null 2>&1 || die 9 "link.add failed: $add_name ($add_type)"
      fi
      ;;
    link.up)
      local up_name
      up_name=$(printf '%s' "$op" | jq -r '.name')
      ip link set dev "$up_name" up >/dev/null 2>&1 || die 9 "link.up failed: $up_name"
      ;;
    sysctl.set)
      local sysctl_key
      local sysctl_value
      local sysctl_path
      sysctl_key=$(printf '%s' "$op" | jq -r '.key | map(tostring) | join("/")')
      sysctl_value=$(printf '%s' "$op" | jq -r '.value')
      sysctl_path="/proc/sys/$sysctl_key"
      if [[ ! -w "$sysctl_path" ]]; then
        die 9 "sysctl.set failed: $sysctl_path is not writable"
      fi
      printf '%s\n' "$sysctl_value" > "$sysctl_path" || die 9 "sysctl.set failed: $sysctl_path"
      ;;
    addr.add)
      local addr_dev
      local addr_cidr
      local addr_base
      addr_dev=$(printf '%s' "$op" | jq -r '.dev')
      addr_cidr=$(management_cidr)
      addr_base=$(strip_prefix "$addr_cidr")
      if ! ip addr add "$addr_cidr" dev "$addr_dev" >/dev/null 2>&1; then
        if ! ip -j addr show dev "$addr_dev" 2>/dev/null | jq -e --arg a "$addr_base" '[.[].addr_info[]?.local] | index($a) != null' >/dev/null; then
          die 9 "addr.add failed: $addr_cidr on $addr_dev"
        fi
      fi
      ;;
    route.add)
      local route_dev
      local route_gw
      route_dev=$(printf '%s' "$op" | jq -r '.dev')
      route_gw=$(printf '%s' "$op" | jq -r '.gateway')
      ip route replace default via "$route_gw" dev "$route_dev" >/dev/null 2>&1 || die 9 "route.add failed: default via $route_gw dev $route_dev"
      ;;
    link.master)
      local master_name
      local master_dev
      master_name=$(printf '%s' "$op" | jq -r '.name')
      master_dev=$(printf '%s' "$op" | jq -r '.master')
      ip link set dev "$master_name" master "$master_dev" >/dev/null 2>&1 || die 9 "link.master failed: $master_name -> $master_dev"
      ;;
    link.set)
      local set_name
      local set_mac
      set_name=$(printf '%s' "$op" | jq -r '.name')
      set_mac=$(printf '%s' "$op" | jq -r '.mac')
      ip link set dev "$set_name" address "$set_mac" >/dev/null 2>&1 || die 9 "link.set failed: $set_name $set_mac"
      ;;
    nft.load)
      apply_nft
      ;;
    *)
      die 9 "unknown plan op: $kind"
      ;;
  esac
}

execute_plan() {
  local count
  local i
  count=$(printf '%s' "$PLAN_JSON" | jq 'length')
  i=0
  while [[ "$i" -lt "$count" ]]; do
    local op
    op=$(printf '%s' "$PLAN_JSON" | jq -c --argjson i "$i" '.[$i]')
    execute_op "$op"
    i=$((i + 1))
  done
}

undo_op() {
  local op="$1"
  local kind
  kind=$(printf '%s' "$op" | jq -r '.op')
  case "$kind" in
    nft.load)
      nft delete table bridge manilov_vm >/dev/null 2>&1 || true
      nft delete table inet manilov_vm >/dev/null 2>&1 || true
      ;;
    route.add)
      local route_dev
      local route_gw
      route_dev=$(printf '%s' "$op" | jq -r '.dev')
      route_gw=$(printf '%s' "$op" | jq -r '.gateway')
      ip route del default via "$route_gw" dev "$route_dev" >/dev/null 2>&1 || true
      ;;
    addr.add)
      local addr_dev
      local addr_cidr
      addr_dev=$(printf '%s' "$op" | jq -r '.dev')
      addr_cidr=$(management_cidr)
      ip addr del "$addr_cidr" dev "$addr_dev" >/dev/null 2>&1 || true
      ;;
    sysctl.set)
      local sysctl_key
      local sysctl_path
      sysctl_key=$(printf '%s' "$op" | jq -r '.key | map(tostring) | join("/")')
      sysctl_path="/proc/sys/$sysctl_key"
      if [[ -w "$sysctl_path" ]]; then
        printf '0\n' > "$sysctl_path" 2>/dev/null || true
      fi
      ;;
    link.master)
      local master_name
      master_name=$(printf '%s' "$op" | jq -r '.name')
      ip link set dev "$master_name" nomaster >/dev/null 2>&1 || true
      ;;
    link.up)
      local up_name
      up_name=$(printf '%s' "$op" | jq -r '.name')
      ip link set dev "$up_name" down >/dev/null 2>&1 || true
      ;;
    link.add)
      local add_name
      add_name=$(printf '%s' "$op" | jq -r '.name')
      ip link del dev "$add_name" >/dev/null 2>&1 || true
      ;;
    assert.linkMac | link.set)
      ;;
  esac
}

undo_plan() {
  local reverse
  local count
  local i
  reverse=$(printf '%s' "$PLAN_JSON" | jq -c 'reverse')
  count=$(printf '%s' "$reverse" | jq 'length')
  i=0
  while [[ "$i" -lt "$count" ]]; do
    local op
    op=$(printf '%s' "$reverse" | jq -c --argjson i "$i" '.[$i]')
    undo_op "$op"
    i=$((i + 1))
  done
}

record_check() {
  local name="$1"
  local status="$2"
  local detail="${3:-}"
  HEALTH_CHECKS_JSON=$(jq -c \
    --arg n "$name" \
    --arg s "$status" \
    --arg d "$detail" \
    '. + [{name:$n,status:$s,detail:(if $d == "" then null else $d end)}]' <<<"$HEALTH_CHECKS_JSON")
  if [[ "$status" == "fail" ]]; then
    HEALTH_OVERALL="fail"
  elif [[ "$status" == "degraded" && "$HEALTH_OVERALL" != "fail" ]]; then
    HEALTH_OVERALL="degraded"
  fi
}

probe_health() {
  HEALTH_CHECKS_JSON="[]"
  HEALTH_OVERALL="pass"
  local tap
  local mgmt
  local gateway

  if [[ "$PROFILE" == "bridge" ]]; then
    if link_exists "br0"; then
      if link_is_up "br0"; then
        record_check "br0-link" "pass" ""
      else
        record_check "br0-link" "degraded" "br0 exists but carrier/operstate is not up"
      fi
    else
      record_check "br0-link" "fail" "br0 is missing"
    fi
    mgmt=$(management_cidr)
    if addr_present "br0" "$mgmt"; then
      record_check "br0-address" "pass" ""
    else
      record_check "br0-address" "fail" "management address $mgmt is missing on br0"
    fi
    gateway=$(printf '%s' "$PARAMS_JSON" | jq -r '.management.gateway // empty')
    if route_present "br0" "$gateway"; then
      record_check "default-route" "pass" ""
    else
      record_check "default-route" "fail" "default route via $gateway dev br0 is missing"
    fi
  else
    tap=$(printf '%s' "$PARAMS_JSON" | jq -r '.datapath.tap // empty')
    if link_exists "$tap"; then
      record_check "tap-link" "pass" ""
    else
      record_check "tap-link" "fail" "tap $tap is missing"
    fi
    mgmt=$(management_cidr)
    if addr_present "$tap" "$mgmt"; then
      record_check "tap-address" "pass" ""
    else
      record_check "tap-address" "fail" "management address $mgmt is missing on $tap"
    fi
  fi

  if sshd_listening; then
    record_check "sshd" "pass" ""
  else
    record_check "sshd" "fail" "sshd is not listening"
  fi
}

stop_deadman() {
  local unit="$1"
  [[ -n "$unit" ]] || return 0
  case "$unit" in
    process:*)
      local pid="${unit#process:}"
      if [[ "$pid" =~ ^[0-9]+$ ]]; then
        # `setsid` makes the child a process-group leader; kill the group so a
        # sleeping dead-man child cannot outlive a confirm/extend.
        kill -- "-$pid" >/dev/null 2>&1 || kill "$pid" >/dev/null 2>&1 || true
      fi
      rm -f "$RUNTIME_DIR/deadman.pid"
      ;;
    *)
      systemctl stop "$unit.timer" "$unit.service" >/dev/null 2>&1 || true
      systemctl reset-failed "$unit.timer" "$unit.service" >/dev/null 2>&1 || true
      ;;
  esac
}

arm_deadman() {
  local seconds="$1"
  local deadline_epoch="$2"
  local unit="manilov-network-deadman-${MARKER_OWNER_ID}"
  local backend="${MANILOV_DEADMAN_BACKEND:-systemd}"

  local -a rollback_args
  rollback_args=(rollback --reason deadman --if-unconfirmed --deadline "$deadline_epoch")
  rollback_args+=(--marker "$MARKER_PATH" --state-dir "$STATE_DIR_OPT")
  if [[ -n "$ROOT" ]]; then
    rollback_args+=(--root "$ROOT")
  fi

  if [[ "$backend" != "process" ]] && command -v systemd-run >/dev/null 2>&1; then
    if systemd-run --unit="$unit" --on-active="${seconds}s" --collect --quiet -- \
      "$0" "${rollback_args[@]}" >/dev/null 2>&1; then
      DEADMAN_UNIT="$unit"
      return 0
    fi
  fi

  if [[ "$backend" == "process" ]]; then
    # Test/fallback backend: wait for the deadline before invoking rollback.
    # Starting the rollback immediately used to race a concurrent
    # confirm/extend for the owner lock; sleeping is also the faithful timer
    # semantics, and `stop_deadman` kills the whole process group to cancel.
    # shellcheck disable=SC2016
    setsid "${BASH:-bash}" -c '
      sleep "$1"
      shift
      exec "$@"
    ' _ "$seconds" "$0" "${rollback_args[@]}" >/dev/null 2>&1 9>&- &
    local pid=$!
    DEADMAN_UNIT="process:$pid"
    mkdir -p "$RUNTIME_DIR"
    printf '%s\n' "$pid" > "$RUNTIME_DIR/deadman.pid"
    return 0
  fi

  die 9 "failed to arm the dead-man timer"
}

arm_and_record_deadman() {
  local seconds="$1"
  local epoch
  epoch=$(( $(now_epoch) + seconds ))
  arm_deadman "$seconds" "$epoch"
  local at
  at=$(now_iso)
  STATE_JSON=$(printf '%s' "$STATE_JSON" | jq -c \
    --arg at "$at" \
    --arg unit "$DEADMAN_UNIT" \
    --argjson cd "$seconds" \
    '.deadmanArmedAt=$at | .deadmanUnit=$unit | .deadmanCancelled=false | .confirmDeadline=$cd | .appliedAt=$at')
  write_state
}

perform_rollback() {
  local reason="$1"
  local unit
  unit=$(state_get '.deadmanUnit // empty')
  stop_deadman "$unit"

  STATE_JSON=$(printf '%s' "$STATE_JSON" | jq -c '.phase="rolling-back"')
  write_state

  undo_plan

  STATE_JSON=$(printf '%s' "$STATE_JSON" | jq -c \
    --arg reason "$reason" \
    '.phase="rolled-back"
    | .health="unknown"
    | .healthChecks=[]
    | .confirmedAt=null
    | .deadmanCancelled=true
    | .deadmanArmedAt=null
    | .handoff={to:"host",reason:$reason}')
  write_state
}

cmd_check() {
  load_marker
  validate_marker
  require_uplink
  check_owner_conflict
  require_host_permit
  load_state

  local phase
  local health
  phase=$(state_get '.phase')
  health=$(state_get '.health')

  if [[ "$JSON_OUT" -eq 1 ]]; then
    emit_status_json
  else
    printf 'manilov-network: check ok (profile=%s, role=%s, phase=%s, health=%s)\n' \
      "$PROFILE" "$MARKER_ROLE" "$phase" "$health"
  fi
}

emit_status_json() {
  local phase
  local health
  local remaining=-1
  local armed=false
  local cancelled
  local last
  phase=$(state_get '.phase')
  health=$(state_get '.health')
  cancelled=$(state_get '.deadmanCancelled // false')
  last=$(state_get '[.healthChecks[]? | select(.status == "fail" or .status == "degraded") | .name] | first // empty')

  if [[ "$phase" == "unconfirmed" ]]; then
    local applied_at
    local confirm_deadline
    applied_at=$(state_get '.appliedAt // empty')
    confirm_deadline=$(state_get '.confirmDeadline // empty')
    if [[ -n "$applied_at" && -n "$confirm_deadline" ]]; then
      local applied_epoch
      applied_epoch=$(date -d "$applied_at" +%s)
      remaining=$((applied_epoch + confirm_deadline - $(now_epoch)))
      if [[ "$remaining" -lt 0 ]]; then
        remaining=0
      fi
    fi
  fi

  local unit
  unit=$(state_get '.deadmanUnit // empty')
  if [[ -n "$unit" && "$cancelled" != "true" ]]; then
    armed=true
  fi

  jq -n -c \
    --arg phase "$phase" \
    --arg health "$health" \
    --argjson remaining "$remaining" \
    --argjson armed "$armed" \
    --argjson cancelled "$cancelled" \
    --arg last "$last" \
    '{phase:$phase,health:$health}
     + (if $remaining >= 0 then {remainingSeconds:$remaining} else {} end)
     + {deadmanArmed:$armed,deadmanCancelled:$cancelled,lastFailingCheck:(if $last == "" then null else $last end)}'
}

cmd_status() {
  load_state
  if [[ "$JSON_OUT" -eq 1 ]]; then
    emit_status_json
    return 0
  fi
  local phase
  local health
  phase=$(state_get '.phase')
  health=$(state_get '.health')
  printf 'phase: %s\n' "$phase"
  printf 'health: %s\n' "$health"
  printf 'profile: %s\n' "$(state_get '.profile')"
  printf 'planDigest: %s\n' "$(state_get '.planDigest // empty')"
  printf 'paramsDigest: %s\n' "$(state_get '.paramsDigest // empty')"
  printf 'confirmDeadline: %s\n' "$(state_get '.confirmDeadline // empty')"
  printf 'deadmanUnit: %s\n' "$(state_get '.deadmanUnit // empty')"
}

cmd_host_permit() {
  if host_permit_ok; then
    if [[ "$JSON_OUT" -eq 1 ]]; then
      printf '{"ok":true}\n'
    else
      printf 'manilov-network: host-permit ok (host filter FORWARD -> MANILOV_FORWARD)\n'
    fi
    return 0
  fi
  die 7 "host-permit-missing: host filter FORWARD does not jump to MANILOV_FORWARD"
}

cmd_apply() {
  load_marker
  validate_marker
  require_owner_mutation
  require_uplink
  require_host_permit
  acquire_lock
  write_owner
  build_plan
  load_state

  local phase
  local state_profile
  local state_plan
  local state_params
  phase=$(state_get '.phase')
  state_profile=$(state_get '.profile')
  state_plan=$(state_get '.planDigest // empty')
  state_params=$(state_get '.paramsDigest // empty')

  if [[ "$phase" == "applied" || "$phase" == "unconfirmed" || "$phase" == "applying" ]]; then
    if [[ "$state_profile" == "$PROFILE" && "$state_plan" == "$plan_digest" && "$state_params" == "$params_digest" ]]; then
      info "apply no-op: profile=$PROFILE phase=$phase"
      return 0
    fi
    die 11 "apply refused: state profile=$state_profile phase=$phase differs from marker/plan"
  fi

  local deadline_seconds
  deadline_seconds=$(printf '%s' "$PARAMS_JSON" | jq -r '.confirmDeadline // empty')
  if [[ -z "$deadline_seconds" ]]; then
    deadline_seconds="${MANILOV_CONFIRM_DEADLINE:-300}"
  fi
  is_uint "$deadline_seconds" || die 8 "confirmDeadline must be a non-negative integer"
  local max_deadline="${MANILOV_MAX_CONFIRM_DEADLINE:-$MAX_CONFIRM_DEADLINE_DEFAULT}"
  is_uint "$max_deadline" || die 8 "maxConfirmDeadline must be a non-negative integer"
  [[ "$deadline_seconds" -le "$max_deadline" ]] || die 8 "confirmDeadline $deadline_seconds exceeds maxConfirmDeadline $max_deadline"

  STATE_JSON=$(printf '%s' "$STATE_JSON" | jq -c \
    --arg phase "applying" \
    --arg profile "$PROFILE" \
    --arg plan "$plan_digest" \
    --arg params "$params_digest" \
    --argjson cd "$deadline_seconds" \
    '.phase=$phase
     | .profile=$profile
     | .planDigest=$plan
     | .paramsDigest=$params
     | .appliedAt=null
     | .confirmDeadline=$cd
     | .confirmedAt=null
     | .deadmanArmedAt=null
     | .deadmanUnit=null
     | .deadmanCancelled=false
     | .health="unknown"
     | .healthChecks=[]
     | .handoff=null')
  write_state

  if [[ "$PROFILE" == "bridge" ]]; then
    local count
    local i
    local armed=0
    count=$(printf '%s' "$PLAN_JSON" | jq 'length')
    i=0
    while [[ "$i" -lt "$count" ]]; do
      local op
      local kind
      op=$(printf '%s' "$PLAN_JSON" | jq -c --argjson i "$i" '.[$i]')
      kind=$(printf '%s' "$op" | jq -r '.op')
      # Arm before the first op that can move L3 or cut management: enslaving
      # the uplink to br0 (`link.master`) breaks management just as surely as
      # replacing the address or the default route. `assert.linkMac`,
      # `link.add`, `link.set` and `link.up` are safe to run unarmed because
      # they do not move L3. Arm once, before the first disruptive op.
      if [[ "$armed" -eq 0 && ( "$kind" == "link.master" || "$kind" == "addr.add" || "$kind" == "route.add" ) ]]; then
        arm_and_record_deadman "$deadline_seconds"
        armed=1
      fi
      execute_op "$op"
      i=$((i + 1))
    done
    if [[ "$armed" -eq 0 ]]; then
      arm_and_record_deadman "$deadline_seconds"
    fi

    probe_health
    STATE_JSON=$(printf '%s' "$STATE_JSON" | jq -c \
      --arg health "$HEALTH_OVERALL" \
      --argjson checks "$HEALTH_CHECKS_JSON" \
      '.health=$health | .healthChecks=$checks')
    write_state

    if [[ "$HEALTH_OVERALL" == "fail" ]]; then
      info "bridge health probe failed; rolling back immediately"
      load_state
      # Reload keeps the health fields just written; PLAN_JSON is unchanged.
      perform_rollback "health"
      exit 10
    fi

    STATE_JSON=$(printf '%s' "$STATE_JSON" | jq -c '.phase="unconfirmed"')
    write_state
    info "apply complete: profile=bridge phase=unconfirmed health=$HEALTH_OVERALL"
    return 0
  fi

  execute_plan
  STATE_JSON=$(printf '%s' "$STATE_JSON" | jq -c \
    --arg at "$(now_iso)" \
    '.phase="applied" | .appliedAt=$at | .health="unknown" | .healthChecks=[]')
  write_state
  info "apply complete: profile=proxyarp phase=applied"
}

cmd_confirm() {
  load_marker
  validate_marker
  require_owner_mutation
  acquire_lock
  write_owner
  build_plan
  load_state

  local phase
  phase=$(state_get '.phase')
  [[ "$phase" == "unconfirmed" ]] || die 11 "confirm refused: phase=$phase (expected unconfirmed)"
  [[ "$(state_get '.profile')" == "$PROFILE" ]] || die 11 "confirm refused: state profile does not match marker"

  local owner_id=""
  if [[ -f "$OWNER_FILE" ]]; then
    owner_id=$(jq -r '.owner.id // empty' "$OWNER_FILE" 2>/dev/null || true)
  fi
  [[ -z "$owner_id" || "$owner_id" == "$MANILOV_IMAGE_ID" ]] || die 11 "confirm refused: owner.id '$owner_id' != image '$MANILOV_IMAGE_ID'"

  local state_plan
  local state_params
  state_plan=$(state_get '.planDigest // empty')
  state_params=$(state_get '.paramsDigest // empty')
  [[ "$state_plan" == "$plan_digest" ]] || die 11 "confirm refused: planDigest mismatch"
  [[ "$state_params" == "$params_digest" ]] || die 11 "confirm refused: paramsDigest mismatch"

  local health
  health=$(state_get '.health')
  case "$health" in
    fail)
      die 11 "confirm refused: health=fail"
      ;;
    degraded)
      [[ "$FORCE" -eq 1 ]] || die 11 "confirm refused: health=degraded requires --force"
      ;;
  esac

  local unit
  unit=$(state_get '.deadmanUnit // empty')
  stop_deadman "$unit"

  STATE_JSON=$(printf '%s' "$STATE_JSON" | jq -c \
    --arg at "$(now_iso)" \
    '.phase="applied" | .confirmedAt=$at | .deadmanCancelled=true')
  write_state
  info "confirm complete: phase=applied"
}

cmd_extend() {
  [[ -n "$TO_VALUE" ]] || die 2 "extend requires --to N"
  is_uint "$TO_VALUE" || die 2 "--to expects a non-negative integer number of seconds"
  local max_deadline="${MANILOV_MAX_CONFIRM_DEADLINE:-$MAX_CONFIRM_DEADLINE_DEFAULT}"
  is_uint "$max_deadline" || die 8 "maxConfirmDeadline must be a non-negative integer"
  # `--to` is a user-supplied CLI bound, so exceeding it is a usage error
  # (exit 2), not a marker/schema error (exit 8).
  [[ "$TO_VALUE" -le "$max_deadline" ]] || die 2 "extend --to $TO_VALUE exceeds maxConfirmDeadline $max_deadline"

  load_marker
  validate_marker
  require_owner_mutation
  acquire_lock
  write_owner
  build_plan
  load_state

  local phase
  phase=$(state_get '.phase')
  [[ "$phase" == "unconfirmed" ]] || die 11 "extend refused: phase=$phase (expected unconfirmed)"

  local applied_at
  local old_deadline
  applied_at=$(state_get '.appliedAt // empty')
  [[ -n "$applied_at" ]] || die 9 "extend refused: appliedAt is missing"
  old_deadline=$(state_get '.confirmDeadline // 0')

  local applied_epoch
  local target_epoch
  local remaining
  applied_epoch=$(date -d "$applied_at" +%s)
  target_epoch=$((applied_epoch + TO_VALUE))
  remaining=$((target_epoch - $(now_epoch)))
  if [[ "$remaining" -lt 0 ]]; then
    remaining=0
  fi

  local unit
  unit=$(state_get '.deadmanUnit // empty')
  stop_deadman "$unit"
  arm_deadman "$remaining" "$target_epoch"

  local at
  local at_epoch
  at=$(now_iso)
  at_epoch=$(now_epoch)
  STATE_JSON=$(printf '%s' "$STATE_JSON" | jq -c \
    --arg at "$at" \
    --argjson at_epoch "$at_epoch" \
    --arg unit "$DEADMAN_UNIT" \
    --argjson from "$old_deadline" \
    --argjson to "$TO_VALUE" \
    --argjson cd "$TO_VALUE" \
    '.confirmDeadline=$cd
     | .deadmanArmedAt=$at
     | .deadmanUnit=$unit
     | .deadmanCancelled=false
     | .extensions += [{at:$at_epoch,from:$from,to:$to}]')
  write_state
  info "extend complete: confirmDeadline=$TO_VALUE (remaining=${remaining}s)"
}

cmd_rollback() {
  local reason="${REASON:-manual}"
  case "$reason" in
    health | deadman | manual | auto) ;;
    *) die 2 "rollback --reason must be health|deadman|manual|auto" ;;
  esac

  load_marker
  validate_marker
  require_owner_mutation
  acquire_lock
  write_owner
  build_plan
  load_state

  local phase
  phase=$(state_get '.phase')

  if [[ "$IF_UNCONFIRMED" -eq 1 ]]; then
    if [[ "$phase" != "unconfirmed" ]]; then
      info "rollback skipped: phase=$phase is not unconfirmed"
      return 0
    fi
    local target_epoch
    if [[ -n "$DEADLINE" ]]; then
      target_epoch="$DEADLINE"
    else
      local applied_at
      local confirm_deadline
      applied_at=$(state_get '.appliedAt // empty')
      confirm_deadline=$(state_get '.confirmDeadline // empty')
      if [[ -z "$applied_at" || -z "$confirm_deadline" ]]; then
        die 9 "cannot compute the unconfirmed deadline"
      fi
      target_epoch=$(( $(date -d "$applied_at" +%s) + confirm_deadline ))
    fi
    if [[ "$(now_epoch)" -lt "$target_epoch" ]]; then
      info "rollback skipped: deadline $target_epoch has not been reached"
      return 0
    fi
  fi

  if [[ "$phase" == "rolled-back" ]]; then
    info "rollback no-op: already rolled back"
    return 0
  fi

  perform_rollback "$reason"
  info "rollback complete: reason=$reason"
}

cmd_watchdog() {
  load_marker
  validate_marker
  require_owner_mutation
  acquire_lock
  write_owner
  build_plan
  load_state

  local phase
  phase=$(state_get '.phase')
  case "$phase" in
    applied | unconfirmed) ;;
    *)
      info "watchdog no-op: phase=$phase"
      return 0
      ;;
  esac

  probe_health
  STATE_JSON=$(printf '%s' "$STATE_JSON" | jq -c \
    --arg health "$HEALTH_OVERALL" \
    --argjson checks "$HEALTH_CHECKS_JSON" \
    '.health=$health | .healthChecks=$checks')
  write_state

  if [[ "$HEALTH_OVERALL" == "fail" ]]; then
    info "watchdog: hard health failure; rolling back"
    load_state
    perform_rollback "auto"
    return 0
  fi

  info "watchdog: health=$HEALTH_OVERALL"
}

if [[ "$PLAN_MODE" -eq 1 ]]; then
  load_marker
  validate_marker
  build_plan
  printf '%s\n' "$PLAN_JSON"
  exit 0
fi

case "$VERB" in
  check) cmd_check ;;
  apply) cmd_apply ;;
  confirm) cmd_confirm ;;
  extend) cmd_extend ;;
  status) cmd_status ;;
  rollback) cmd_rollback ;;
  watchdog) cmd_watchdog ;;
  host-permit) cmd_host_permit ;;
esac
