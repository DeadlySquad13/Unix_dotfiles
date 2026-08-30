{
  pkgs,
  lib,
  ...
}: let
  module = ../../modules/nixos/services/runtime-home-bridge;
  # The reusable module reads `lib.ds-omega.mkIfEnabled` (repo lib namespace).
  # In the real flake Snowfall injects that namespaced lib; here we mock it so
  # the module's config body is applied unconditionally, which the check wants.
  # We replicate `mkIfEnabled`'s final wrapping: `{ config = <body>; }`.
  mkIfEnabledMock = _opts: module: { config = module; };
  libWithNamespace = lib // {
    ds-omega = lib // {
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
  nativeBuildInputs = [ validSystem.config.services.runtime-home-bridge.package ];
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
  touch $out
''
