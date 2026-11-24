#!/usr/bin/env bash
# Local smoke test for the applier using the checked-in fixtures and fake
# `ip`/`nft`/`ss`/systemd tools. It never touches the real network.
#
# Usage: ./smoke.sh [terra|salt]
#   terra -> full bridge lifecycle (default)
#   salt  -> proxyarp read-only check + resolved plan; apply needs a real tap
#            and /proc/sys/net/ipv4/conf/<tap>/proxy_arp, so it is not run here.
set -euo pipefail

fixture="${1:-terra}"
case "$fixture" in
  terra | salt) ;;
  *)
    printf 'usage: %s [terra|salt]\n' "$0" >&2
    exit 2
    ;;
esac

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../.." && pwd)
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/manilov-smoke.XXXXXX")
cleanup() {
  rm -rf "$sandbox"
}
trap cleanup EXIT

mkdir -p "$sandbox/etc/manilov"
cp "$here/$fixture.json" "$sandbox/etc/manilov/marker.json"

# `MANILOV_NETWORK_BIN` lets the Nix check supply an already-built applier
# (the build sandbox has no `nix`). Direct invocation still builds it.
if [[ -n "${MANILOV_NETWORK_BIN:-}" ]]; then
  store_bin_bin="$MANILOV_NETWORK_BIN"
else
  store_bin=$(nix build --no-link --print-out-paths "$repo#manilov-network" | tail -n 1)
  store_bin_bin="$store_bin/bin/manilov-network"
fi
runner="$sandbox/manilov-network"
sed "s|^export PATH=\"|export PATH=\"$here/fake-bin:|" "$store_bin_bin" > "$runner"
chmod +x "$runner"

export MANILOV_FAKE_NETLINK="$here/netlink-$fixture.json"
export MANILOV_FAKE_NFT_RULESET="$here/nft-host-permit.json"
export MANILOV_FAKE_LOG="$sandbox/fake.log"
# Preserve an outer override so the pure check can force the process dead-man.
export MANILOV_DEADMAN_BACKEND="${MANILOV_DEADMAN_BACKEND:-systemd}"

common=(--root "$sandbox" --state-dir /var/lib/manilov-network --netlink-fixture "$here/netlink-$fixture.json")

if [[ "$fixture" == "salt" ]]; then
  "$runner" check "${common[@]}"
  "$runner" --plan --marker /etc/manilov/marker.json "${common[@]}"
else
  "$runner" apply "${common[@]}"
  "$runner" status --json "${common[@]}"
  "$runner" extend --to 600 "${common[@]}"
  "$runner" confirm "${common[@]}"
  "$runner" rollback --reason manual "${common[@]}"
  "$runner" status --json "${common[@]}"
fi

printf '\nfake-tool commands:\n'
cat "$MANILOV_FAKE_LOG" 2>/dev/null || true
