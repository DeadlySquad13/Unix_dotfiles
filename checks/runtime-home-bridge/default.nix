{
  pkgs,
  lib,
  namespace,
  inputs,
  ...
}: let
  module = ../../modules/nixos/services/runtime-home-bridge;
  # The reusable module reads `lib.ds-omega.mkIfEnabled` (repo lib namespace)
  # and the runtime-home-bridge lib (`catalogJsonContent`/`mkResolutions`).
  # In the real flake Snowfall injects that namespaced lib; here we mock it so
  # the module's config body is applied unconditionally, which the check
  # wants, while merging the real bridge lib (same pattern as the `bookmarks`
  # check). We replicate `mkIfEnabled`'s final wrapping: `{ config = <body>; }`.
  mkIfEnabledMock = _opts: module: { config = module; };
  bridgeLib = import ../../lib/runtime-home-bridge {
    inherit inputs namespace;
    lib = lib // {
      ${namespace} = {
        disabled = { enable = false; };
        enabled = { enable = true; };
      };
    };
  };
  libWithNamespace = lib // {
    ds-omega = bridgeLib // {
      mkIfEnabled = mkIfEnabledMock;
    };
  };
  mkSystem = extraModule:
    lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      specialArgs = {
        lib = libWithNamespace;
      };
      modules = [ module extraModule ];
    };

  validSystem = mkSystem {
    services.runtime-home-bridge = {
      user = "bridge-test";
      homeDirectory = "/tmp/bridge-home";
      namespaceRoot = "/tmp/bridge-namespace";
      zNamespaceRoot = "/tmp/z-namespace";
      catalogArtifactPath = "/tmp/bridge-namespace/_runtime/catalog-artifact.json";
      variants = {
        default = [
          { source = "_configs"; target = ".bookmarks/shared-configs"; }
        ];
        withZ = [
          {
            zSource = "shared-/@salt/z-data";
            source = "_zdata";
            target = ".bookmarks/z-data";
          }
        ];
        # Regression fixture: the source is a symlink to an existing mount, so
        # the canonical home target becomes a symlink whose referent is a
        # mountpoint. `findmnt --mountpoint` follows symlinks, so a naive
        # mountpoint check rejects the bridge's own correct link on the next
        # run. The script below re-runs this variant to prove idempotency.
        mountLike = [
          { source = "_mountsrc"; target = ".bookmarks/mount-like"; }
        ];
      };
    };
  };

  invalidSystem = mkSystem {
    services.runtime-home-bridge = {
      user = "bridge-test";
      homeDirectory = "/tmp/bridge-home";
      namespaceRoot = "/tmp/bridge-namespace";
      zNamespaceRoot = "/tmp/z-namespace";
      variants.default = [ { source = "../escape"; target = "/absolute"; } ];
    };
  };
in
assert !(builtins.tryEval invalidSystem.config.system.build.toplevel).success;
pkgs.runCommand "runtime-home-bridge" {
  nativeBuildInputs = [
    validSystem.config.services.runtime-home-bridge.package
    pkgs.jq
    pkgs.util-linux
  ];
} ''
    set -euo pipefail
    namespace="/tmp/bridge-namespace"; home="/tmp/bridge-home"
    z="/tmp/z-namespace"
    rm -rf "$namespace" "$home" "$z"
    mkdir -p "$namespace/_configs" "$namespace/_runtime" "$home" "$z/shared-/@salt/z-data" "$z/_runtime"

    # Variant without zSource: home target -> namespace source.
    printf '{"version":1,"variant":"default"}' > "$namespace/_runtime/home-bridge.json"
    runtime-home-bridge
    test "$(readlink "$home/.bookmarks/shared-configs")" = "$namespace/_configs"

    # Variant with zSource: home target -> namespace source -> z namespace.
    printf '{"version":1,"variant":"withZ"}' > "$namespace/_runtime/home-bridge.json"
    runtime-home-bridge
    mkdir -p "$namespace/_zdata"
    test "$(readlink "$home/.bookmarks/z-data")" = "$namespace/_zdata"
    test "$(readlink "$namespace/_zdata")" = "$z/shared-/@salt/z-data"

    # Regression: a canonical symlink whose referent is a real mountpoint must
    # be accepted on the first run and must remain idempotent on the next. Use
    # whichever mountpoint is available in the build sandbox as the referent.
    mount_ref=""
    for candidate in /nix/store /proc /dev /sys; do
      if findmnt -n --mountpoint "$candidate" >/dev/null 2>&1; then
        mount_ref="$candidate"
        break
      fi
    done
    if [ -n "$mount_ref" ]; then
      ln -s "$mount_ref" "$namespace/_mountsrc"
      printf '{"version":1,"variant":"mountLike"}' > "$namespace/_runtime/home-bridge.json"
      runtime-home-bridge
      test "$(readlink "$home/.bookmarks/mount-like")" = "$namespace/_mountsrc"
      # Before the fix this second run failed with
      # "canonical target is a mountpoint" because findmnt resolves symlinks.
      runtime-home-bridge
    else
      echo "warning: skipping symlink-to-mountpoint regression (no mountpoint found)" >&2
    fi

    # Full catalog artifact was emitted (ADDITIVE) and is valid JSON with the
    # interchange contract fields, including resolved host paths.
    artifact="$namespace/_runtime/catalog-artifact.json"
    test -f "$artifact"
    test "$(jq -er '.version' "$artifact")" = 1
    jq -e '.homeDirectory == "/tmp/bridge-home" and .zNamespaceRoot == "/tmp/z-namespace"' "$artifact" >/dev/null
    jq -e '.resolutions["/tmp/bridge-home/.bookmarks/z-data"] == "/tmp/z-namespace/shared-/@salt/z-data"' "$artifact" >/dev/null
  touch $out
''
