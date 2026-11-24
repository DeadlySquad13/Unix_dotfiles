{
  pkgs,
  lib,
  ...
}: let
  package = pkgs.callPackage ../../packages/manilov-network {};
  fixtures = ../../tests/fixtures/manilov;
in
  pkgs.runCommand "manilov-network-pure" {
    nativeBuildInputs = [
      package
      pkgs.bash
      pkgs.coreutils
      pkgs.gnused
      pkgs.gnugrep
      pkgs.jq
      pkgs.util-linux
    ];
  } ''
    set -euo pipefail

    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT

    # Copy the fixtures into the writable sandbox so the fake-bin shebangs can
    # be rewritten to store paths (the build sandbox has no /usr/bin/env) and
    # so smoke.sh's own `here/fake-bin` injection points at the patched copies.
    fixtures="$work/fixtures"
    cp -r ${fixtures}/. "$fixtures/"
    chmod -R u+w "$fixtures"
    patchShebangs "$fixtures/fake-bin"

    pkg_bin=${lib.escapeShellArg "${package}/bin/manilov-network"}
    runner="$work/manilov-network"
    sed "s|^export PATH=\"|export PATH=\"$fixtures/fake-bin:|" "$pkg_bin" > "$runner"
    chmod +x "$runner"

    export PATH="$fixtures/fake-bin:$PATH"
    export MANILOV_DEADMAN_BACKEND=process
    export MANILOV_FAKE_NFT_RULESET="$fixtures/nft-host-permit.json"

    run_case() {
      local name="$1"
      local expected="$2"
      shift 2
      printf '\n[case] %s (expect %s)\n' "$name" "$expected"
      set +e
      "$@"
      local rc=$?
      set -e
      printf '[case] %s -> exit %s\n' "$name" "$rc"
      if [ "$rc" -ne "$expected" ]; then
        printf 'FAIL: %s expected %s got %s\n' "$name" "$expected" "$rc" >&2
        exit 1
      fi
    }

    new_root() {
      local name="$1"
      local marker="$2"
      local root="$work/$name"
      mkdir -p "$root/etc/manilov" "$root/run/manilov-network" "$root/var/lib/manilov-network"
      cp "$fixtures/$marker" "$root/etc/manilov/marker.json"
      printf '%s' "$root"
    }

    # 1/2. The checked-in smoke script (terra lifecycle, salt check+plan).
    export MANILOV_NETWORK_BIN="$pkg_bin"
    run_case smoke-terra 0 bash "$fixtures/smoke.sh" terra
    run_case smoke-salt 0 bash "$fixtures/smoke.sh" salt

    # 2c. host-permit fixture shapes: ip -> 0, inet -> 0, no-drop -> 7,
    # dual-partial -> 7, dual-ok -> 0.
    export MANILOV_FAKE_NFT_RULESET="$fixtures/nft-host-permit.json"
    run_case host-permit-ip 0 "$runner" host-permit
    export MANILOV_FAKE_NFT_RULESET="$fixtures/nft-host-permit-inet.json"
    run_case host-permit-inet 0 "$runner" host-permit
    export MANILOV_FAKE_NFT_RULESET="$fixtures/nft-host-permit-no-drop.json"
    run_case host-permit-no-drop 7 "$runner" host-permit
    export MANILOV_FAKE_NFT_RULESET="$fixtures/nft-host-permit-dual-drop.json"
    run_case host-permit-dual-partial 7 "$runner" host-permit
    export MANILOV_FAKE_NFT_RULESET="$fixtures/nft-host-permit-dual-drop-ok.json"
    run_case host-permit-dual-ok 0 "$runner" host-permit
    export MANILOV_FAKE_NFT_RULESET="$fixtures/nft-host-permit.json"

    # 3. Bad selector digest is a marker/digest error (exit 3).
    root=$(new_root bad-digest bad-digest.json)
    run_case check-bad-digest 3 "$runner" check \
      --root "$root" --marker /etc/manilov/marker.json

    # 4. A consumer marker may not apply (exit 12).
    root=$(new_root consumer consumer.json)
    run_case apply-consumer 12 "$runner" apply \
      --root "$root" --marker /etc/manilov/marker.json

    # 5. Confirm outside the unconfirmed phase is refused (exit 11).
    root=$(new_root confirm-wrong terra.json)
    run_case confirm-wrong-phase 11 "$runner" confirm \
      --root "$root" --marker /etc/manilov/marker.json

    # 6. Extend past maxConfirmDeadline is a usage error (exit 2). Build a
    # real unconfirmed bridge state first with the fake tools.
    root=$(new_root extend-901 terra.json)
    "$runner" apply --root "$root" --marker /etc/manilov/marker.json \
      --netlink-fixture "$fixtures/netlink-terra.json" >/dev/null
    phase=$("$runner" status --json --root "$root" | jq -r .phase)
    if [ "$phase" != "unconfirmed" ]; then
      printf 'FAIL: extend-901 setup expected phase unconfirmed, got %s\n' "$phase" >&2
      exit 1
    fi
    run_case extend-901 2 "$runner" extend --to 901 \
      --root "$root" --marker /etc/manilov/marker.json
    if [ -f "$root/run/manilov-network/deadman.pid" ]; then
      kill "$(cat "$root/run/manilov-network/deadman.pid")" 2>/dev/null || true
    fi

    # 7/8. Help and version are clean exits and carry the expected strings.
    run_case help 0 "$runner" --help
    run_case version 0 "$runner" --version
    "$runner" --help | grep -q 'Usage: manilov-network'
    "$runner" --help | grep -q 'Exit codes:'
    "$runner" --version | grep -q 'manilov-network 1.0.0'

    echo "manilov-network pure cases OK" > "$out"
  ''
