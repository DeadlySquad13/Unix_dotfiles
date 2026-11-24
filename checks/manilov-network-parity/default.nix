{
  pkgs,
  lib,
  namespace,
  inputs,
  ...
}: let
  # Mock only the Snowfall enablement wrapper; the real system files read
  # `lib.ds-omega.{disabled,enabled}` and the module reads
  # `lib.ds-omega.mkIfEnabled`. Applying the module body unconditionally is
  # correct here because both hosts enable the module.
  mkIfEnabledMock = _opts: module: { config = module; };
  libWithNamespace =
    lib
    // {
      # Merge the real namespace first, then override the wrapper so a real
      # `mkIfEnabled` cannot win.
      ds-omega =
        (lib.ds-omega or {})
        // {
          disabled = {enable = false;};
          enabled = {enable = true;};
          mkIfEnabled = mkIfEnabledMock;
        };
    };

  # The real system files assign `lib.ds-omega.modules...` as module config.
  # Snowfall declares `options.lib`; a standalone lib.nixosSystem does not, so
  # provide the same free-form option locally.
  libOptionModule = {lib, ...}: {
    options.lib = lib.mkOption {
      type = lib.types.raw;
      default = {};
      description = "Snowfall-style config.lib namespace used by the host files.";
    };
  };

  mkNode = systemModules:
    lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      specialArgs = {
        lib = libWithNamespace;
        inherit inputs namespace;
        host = "NikolaiGogol";
        home = "x86_64-linux";
        target = "nixos";
        format = "nixos";
        virtual = false;
      };
      modules =
        [
          ../../modules/nixos/services/manilov-network
          libOptionModule
          {system.stateVersion = "24.11";}
        ]
        ++ systemModules;
    };

  dockerNode = mkNode [../../systems/x86_64-docker/NikolaiGogol];
  innerNode = mkNode [../../systems/x86_64-linux/NikolaiGogol_inner];
  defaultNode = mkNode [];

  contractOf = node:
    builtins.tryEval (
      let
        v = node.config.services.manilov-network;
      in
        builtins.deepSeq [v.effective v.modulePath] {
          inherit (v) effective modulePath;
        }
    );

  docker = contractOf dockerNode;
  inner = contractOf innerNode;
  default = contractOf defaultNode;

  same = a: b: a.effective == b.effective && a.modulePath == b.modulePath;

  defaultContract =
    if default.success
    then default.value
    else {
      effective = {};
      modulePath = "unavailable";
    };

  result =
    if inner.success && docker.success
    then
      if same inner.value docker.value
      then {
        ok = true;
        message = "parity: identical (docker NikolaiGogol vs NikolaiGogol_inner)";
        value = inner.value;
      }
      else {
        ok = false;
        message = "parity: MISMATCH between docker NikolaiGogol and NikolaiGogol_inner";
        value = inner.value;
      }
    else if inner.success
    then {
      ok = same inner.value defaultContract;
      message = "parity: FALLBACK (docker system did not evaluate in isolation: docker.success=${toString docker.success}); compared NikolaiGogol_inner with the module at default options";
      value = inner.value;
    }
    else if docker.success
    then {
      ok = same docker.value defaultContract;
      message = "parity: FALLBACK (inner system did not evaluate in isolation: inner.success=${toString inner.success}); compared docker NikolaiGogol with the module at default options";
      value = docker.value;
    }
    else {
      ok = false;
      message = "parity: FAILED (inner.success=${toString inner.success}, docker.success=${toString docker.success}); neither system file evaluated in isolation";
      value = defaultContract;
    };
in
  if result.ok
  then
    pkgs.runCommand "manilov-network-parity" {} ''
      {
        echo ${lib.escapeShellArg result.message}
        echo "modulePath:" ${lib.escapeShellArg result.value.modulePath}
        echo "effective:" ${lib.escapeShellArg (builtins.toJSON result.value.effective)}
      } > "$out"
    ''
  else
    throw result.message
