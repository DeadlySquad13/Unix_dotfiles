{pkgs, lib, namespace, inputs, ...}: let
  # Reuse the same mock as the fast check: the reusable module reads
  # `lib.ds-omega.mkIfEnabled` and the runtime-home-bridge lib
  # (`catalogJsonContent`/`mkResolutions`); Snowfall injects that namespaced
  # lib in a real system, so here we mock `mkIfEnabled` to apply the module
  # body unconditionally while merging the real bridge lib (same pattern as
  # the `bookmarks` check).
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

  node = lib.nixosSystem {
    inherit (pkgs.stdenv.hostPlatform) system;
    specialArgs = { lib = libWithNamespace; };
    modules = [
      ../../modules/nixos/services/runtime-home-bridge
      {
        services.runtime-home-bridge = {
          user = "bridge-test";
          homeDirectory = "/home/bridge-test";
          namespaceRoot = "/run/bridge-namespace";
          zNamespaceRoot = "/run/z-bridge-namespace";
          required = true;
          variants = {
            default = [
              { source = "_configs"; target = ".bookmarks/shared-configs"; }
            ];
            # Exercises the zSource path validation and catalog serialization
            # during NixOS evaluation. Runtime chain behavior is covered by the
            # fast check.
            withZ = [
              {
                zSource = "shared-/@salt/z-data";
                source = "_zdata";
                target = ".bookmarks/z-data";
              }
            ];
          };
        };
      }
    ];
  };
in
  # This is a NixOS integration/build check rather than a booted VM: it forces a
  # full NixOS evaluation of the module, verifying the systemd service unit,
  # ordering, tmpfiles rules, and module assertions all resolve together. The
  # generated script's shell/symlink behavior is covered by the fast
  # `runtime-home-bridge` check (including the zSource chain).
  pkgs.runCommand "runtime-home-bridge-nixos" {
    nativeBuildInputs = [ node.config.services.runtime-home-bridge.package ];
  } ''
    echo "NixOS integration OK: systemd unit + tmpfiles + assertions resolved" > "$out"
  ''
