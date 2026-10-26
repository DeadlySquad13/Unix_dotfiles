{
  pkgs,
  lib,
  namespace,
  inputs,
  ...
}: let
  # Integration check for the darkGreen host glue around `sops-npmjs`. It
  # imports the REAL per-host modules (without evaluating a full system/home)
  # and asserts the system permission/runtime-path facts, the home
  # `systemRuntimePath` mapping, host import/enable wiring, and that the stale
  # `ecosystem.sops.npmrc` option is gone.
  #
  # Run:
  #   nix build --offline --impure .#checks.x86_64-linux.sops-npmjs-glue

  repo = ../..;

  systemHost = repo + "/systems/x86_64-docker/darkGreen-tangerineDream/default.nix";
  systemHostGreen = repo + "/systems/x86_64-docker/darkGreen-tangerineDream-green/default.nix";
  systemGlue = repo + "/systems/x86_64-docker/darkGreen-tangerineDream/apps/ecosystem/sops-npmjs/default.nix";
  systemGlueGreen = repo + "/systems/x86_64-docker/darkGreen-tangerineDream-green/apps/ecosystem/sops-npmjs/default.nix";

  homeHost = repo + "/homes/x86_64-linux/tangerineDream@darkGreen-tangerineDream/default.nix";
  homeHostGreen = repo + "/homes/x86_64-linux/tangerineDream-green@darkGreen-tangerineDream-green/default.nix";
  homeGlue = repo + "/homes/x86_64-linux/tangerineDream@darkGreen-tangerineDream/apps/ecosystem/sops-npmjs/default.nix";
  homeGlueGreen = repo + "/homes/x86_64-linux/tangerineDream-green@darkGreen-tangerineDream-green/apps/ecosystem/sops-npmjs/default.nix";

  staleSopsFiles = [
    (repo + "/systems/x86_64-docker/darkGreen-tangerineDream/apps/ecosystem/sops/default.nix")
    (repo + "/systems/x86_64-docker/darkGreen-tangerineDream-green/apps/ecosystem/sops/default.nix")
  ];

  # Glue modules call `mkIfEnabled`; for direct (non-module-system) inspection
  # apply the body unconditionally so the configured values are readable.
  glueBaseLib = lib // {
    mkIf = _: x: x;
    ${namespace} = {
      disabled = { enable = false; };
      enabled = { enable = true; };
    };
  };
  glueModulesLib = import (repo + "/lib/modules") {
    inherit inputs namespace;
    lib = glueBaseLib;
  };
  libForGlue = lib.extend (_: _: { ${namespace} = glueModulesLib; });

  # Host top-level modules need their full argument set even though only
  # `imports` and `lib.<namespace>.modules` are inspected.
  hostLib = lib // {
    ${namespace} = {
      disabled = { enable = false; };
      enabled = { enable = true; };
    };
  };
  hostArgs = {
    lib = hostLib;
    inherit namespace;
    pkgs = {};
    inputs = {};
    home = "x86_64-linux";
    target = "x86_64-linux";
    format = "home";
    virtual = false;
    host = "check";
    config = {};
  };

  loadHost = path: import path hostArgs;

  loadSystemGlue = path: baseName:
    (import path {
      inherit namespace;
      lib = libForGlue;
      config = {
        lib.${namespace} = {
          common.systemBaseName = baseName;
          modules.ecosystem.sops-npmjs.enable = true;
        };
      };
    }).config.${namespace}.ecosystem.sops-npmjs;

  loadHomeGlue = path:
    (import path {
      inherit namespace;
      lib = libForGlue;
      config = {
        lib.${namespace}.modules.ecosystem.sops-npmjs.enable = true;
      };
    }).config.${namespace}.ecosystem.sops-npmjs;

  darkGreen = loadSystemGlue systemGlue "tangerineDream";
  darkGreenGreen = loadSystemGlue systemGlueGreen "tangerineDream-green";

  darkGreenHome = loadHomeGlue homeGlue;
  darkGreenGreenHome = loadHomeGlue homeGlueGreen;

  darkGreenHost = loadHost systemHost;
  darkGreenGreenHost = loadHost systemHostGreen;
  darkGreenHomeHost = loadHost homeHost;
  darkGreenGreenHomeHost = loadHost homeHostGreen;

  hasImport = host: suffix:
    lib.any (p: lib.hasSuffix suffix (toString p)) host.imports;

  enabled = host: host.lib.${namespace}.modules.ecosystem.sops-npmjs.enable or false;

  listNix = dir:
    lib.filter
    (p: lib.hasSuffix ".nix" (toString p))
    (lib.filesystem.listFilesRecursive dir);
  staleRef = "ecosystem.sops.npmrc";
  staleRefs =
    lib.filter
    (p: lib.hasInfix staleRef (builtins.readFile p))
    (listNix (repo + "/modules") ++ listNix (repo + "/homes") ++ listNix (repo + "/systems"));

  expectedRuntimePath = "/run/secrets/rendered/npmrc";
  expectedNpmjsImport = "apps/ecosystem/sops-npmjs/default.nix";
  expectedStaleSopsImport = "apps/ecosystem/sops/default.nix";

  check = name: cond: msg:
    if cond
    then true
    else builtins.abort "sops-npmjs-glue FAIL: ${name}: ${msg}";
in
  assert check "system-glue/darkGreen/username"
  (darkGreen.username == "tangerineDream")
  "system glue must set username from systemBaseName";
  assert check "system-glue/darkGreen/group" (darkGreen.group == "users")
  "system glue must set group = users";
  assert check "system-glue/darkGreen/mode" (darkGreen.mode == "0400")
  "system glue must set mode = 0400";
  assert check "system-glue/darkGreen/runtimePath"
  (darkGreen.runtimePath == expectedRuntimePath)
  "system glue must set the agreed runtime path";
  assert check "system-glue/green/username"
  (darkGreenGreen.username == "tangerineDream-green")
  "green system glue must set username from systemBaseName";
  assert check "system-glue/green/group" (darkGreenGreen.group == "users")
  "green system glue must set group = users";
  assert check "system-glue/green/mode" (darkGreenGreen.mode == "0400")
  "green system glue must set mode = 0400";
  assert check "system-glue/green/runtimePath"
  (darkGreenGreen.runtimePath == expectedRuntimePath)
  "green system glue must set the agreed runtime path";
  assert check "home-glue/darkGreen/systemRuntimePath"
  (darkGreenHome.systemRuntimePath == expectedRuntimePath)
  "darkGreen home glue must point at the system-rendered npmrc";
  assert check "home-glue/green/systemRuntimePath"
  (darkGreenGreenHome.systemRuntimePath == expectedRuntimePath)
  "darkGreen-green home glue must point at the system-rendered npmrc";
  assert check "host/system-darkGreen/import"
  (hasImport darkGreenHost expectedNpmjsImport)
  "darkGreen system host must import the sops-npmjs glue";
  assert check "host/system-darkGreen/enable" (enabled darkGreenHost)
  "darkGreen system host must enable sops-npmjs";
  assert check "host/system-green/import"
  (hasImport darkGreenGreenHost expectedNpmjsImport)
  "darkGreen-green system host must import the sops-npmjs glue";
  assert check "host/system-green/enable" (enabled darkGreenGreenHost)
  "darkGreen-green system host must enable sops-npmjs";
  assert check "host/home-darkGreen/import"
  (hasImport darkGreenHomeHost expectedNpmjsImport)
  "darkGreen home host must import the sops-npmjs glue";
  assert check "host/home-darkGreen/enable" (enabled darkGreenHomeHost)
  "darkGreen home host must enable sops-npmjs";
  assert check "host/home-green/import"
  (hasImport darkGreenGreenHomeHost expectedNpmjsImport)
  "darkGreen-green home host must import the sops-npmjs glue";
  assert check "host/home-green/enable" (enabled darkGreenGreenHomeHost)
  "darkGreen-green home host must enable sops-npmjs";
  assert check "host/no-stale-sops-import"
  (!(hasImport darkGreenHost expectedStaleSopsImport)
    && !(hasImport darkGreenGreenHost expectedStaleSopsImport)
    && !(hasImport darkGreenHomeHost expectedStaleSopsImport)
    && !(hasImport darkGreenGreenHomeHost expectedStaleSopsImport))
  "hosts must not import the retired apps/ecosystem/sops glue";
  assert check "stale/files-exist"
  (lib.all builtins.pathExists staleSopsFiles)
  "the neutralized stale files must still exist (or be deleted deliberately)";
  assert check "stale/no-ecosystem-sops-npmrc"
  (lib.all (p: !(lib.hasInfix staleRef (builtins.readFile p))) staleSopsFiles)
  "stale system files must not reference the removed ds-omega.ecosystem.sops.npmrc option";
  assert check "stale/no-references-anywhere"
  (builtins.length staleRefs == 0)
  "no .nix file under modules/homes/systems may reference ds-omega.ecosystem.sops.npmrc";
  pkgs.runCommand "sops-npmjs-glue" {} ''
    echo "sops-npmjs host glue checks OK" > "$out"
  ''
