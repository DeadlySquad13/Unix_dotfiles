{
  pkgs,
  lib,
  ...
}: let
  # Forbidden host/identity literals. RFC 5737 fixtures live under `tests/`
  # and are deliberately not scanned.
  pattern = "DEPLOY_HOST|terra-local|@terra|@salt|\\b(eth0|eth1|wlan0)\\b|192\\.168\\.|10\\.[0-9]+\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.|6c:bf:b5";

  moduleDir = ../../modules/nixos/services/manilov-network;
  dockerSystem = ../../systems/x86_64-docker/NikolaiGogol/default.nix;
  innerSystem = ../../systems/x86_64-linux/NikolaiGogol_inner/default.nix;
in
  pkgs.runCommand "manilov-network-no-host-literals" {
    nativeBuildInputs = [pkgs.gnugrep];
  } ''
    set -euo pipefail
    pattern=${lib.escapeShellArg pattern}

    set +e
    matches=$(grep -RInE -- "$pattern" ${moduleDir} ${dockerSystem} ${innerSystem})
    rc=$?
    set -e

    if [ "$rc" -eq 0 ]; then
      printf 'forbidden host literal(s) found:\n%s\n' "$matches" >&2
      exit 1
    fi
    if [ "$rc" -ne 1 ]; then
      printf 'grep failed with exit %s\n' "$rc" >&2
      exit "$rc"
    fi

    {
      echo "manilov-network no-host-literals OK"
      echo "scanned:"
      echo "  ${moduleDir}"
      echo "  ${dockerSystem}"
      echo "  ${innerSystem}"
    } > "$out"
  ''
