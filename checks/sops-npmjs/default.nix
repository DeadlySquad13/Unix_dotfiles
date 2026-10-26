{
  pkgs,
  lib,
  namespace,
  inputs,
  ...
}: let
  # Integration check for the system (`modules/nixos`) side of the SOPS npm
  # domain split. It evaluates the REAL base `sops`, `sops-opencode`, and
  # `sops-npmjs` modules together with the real sops-nix NixOS module, then
  # asserts ownership, enable gating, template contents, and permissions.
  #
  # Run:
  #   nix build --offline --impure .#checks.x86_64-linux.sops-npmjs

  repo = ../..;
  sopsNpmjs = repo + "/modules/nixos/ecosystem/sops-npmjs/default.nix";
  baseSops = repo + "/modules/nixos/ecosystem/sops/default.nix";
  sopsOpencode = repo + "/modules/nixos/ecosystem/sops-opencode/default.nix";

  # Reproduce Snowfall's flat lib namespace (`lib.<namespace>`). `lib/modules`
  # only needs the disabled/enabled sugar at import time; the module graph below
  # supplies the real `mkIfEnabled`.
  modulesLib = import (repo + "/lib/modules") {
    inherit inputs namespace;
    lib = lib // {
      ${namespace} = {
        disabled = { enable = false; };
        enabled = { enable = true; };
      };
    };
  };
  libWithNamespace = lib.extend (_: _: { ${namespace} = modulesLib; });

  mkSystem = extra: lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    specialArgs = {
      lib = libWithNamespace;
      inherit namespace inputs;
    };
    modules = [
      inputs.sops-nix.nixosModules.sops
      baseSops
      sopsNpmjs
      sopsOpencode
      {
        sops.age.keyFile = "/tmp/sops-npmjs-check-age.txt";
        # Required by sops-opencode even when its domain is disabled.
        # Required by sops-npmjs even when its domain is disabled.
        ${namespace} = {
          ai-assistance.opencode.username = "alice";
          ecosystem.sops-npmjs = {
            username = "alice";
            group = "users";
            mode = "0400";
          };
        };
      }
      extra
    ];
  };

  # Base SOPS alone (no sops-npmjs module in the graph at all).
  baseOnly = mkSystem {
    lib.${namespace}.modules.ecosystem = {
      sops.enable = true;
      sops-opencode.enable = false;
    };
  };

  # sops-opencode enabled, npm domain disabled.
  opencodeNoNpm = mkSystem {
    lib.${namespace}.modules.ecosystem = {
      sops.enable = true;
      sops-opencode.enable = true;
      sops-npmjs.enable = false;
    };
  };

  # npm domain explicitly disabled (module present, enable = false).
  npmOff = mkSystem {
    lib.${namespace}.modules.ecosystem = {
      sops.enable = true;
      sops-opencode.enable = true;
      sops-npmjs.enable = false;
    };
  };

  # npm domain enabled.
  npmOn = mkSystem {
    lib.${namespace}.modules.ecosystem = {
      sops.enable = true;
      sops-opencode.enable = false;
      sops-npmjs.enable = true;
    };
  };

  content = npmOn.config.sops.templates."npmrc".content;
  placeholder = npmOn.config.sops.placeholder.npmjs_auth_token;
  expectedContent = "registry=https://registry.yarnpkg.com\n//registry.npmjs.org/:_authToken=${placeholder}\n";

  hasNpmSecret = config: config.sops.secrets ? "npmjs_auth_token";
  hasNpmTemplate = config: config.sops.templates ? "npmrc";

  npmNixSource = builtins.readFile sopsNpmjs;
  baseNixSource = builtins.readFile baseSops;
  opencodeNixSource = builtins.readFile sopsOpencode;

  check = name: cond: msg:
    if cond
    then true
    else builtins.abort "sops-npmjs FAIL: ${name}: ${msg}";
in
  assert check "base-sops/no-npm-secret" (!(hasNpmSecret baseOnly.config))
  "base sops must not declare npmjs_auth_token";
  assert check "base-sops/no-npm-template" (!(hasNpmTemplate baseOnly.config))
  "base sops must not declare the npmrc template";
  assert check "base-sops/does-not-enable-npm"
  (!(hasNpmSecret baseOnly.config) && !(hasNpmTemplate baseOnly.config))
  "enabling base sops alone must not enable npm artifacts";
  assert check "sops-opencode/no-npm-secret" (!(hasNpmSecret opencodeNoNpm.config))
  "sops-opencode must not declare npmjs_auth_token";
  assert check "sops-opencode/no-npm-template" (!(hasNpmTemplate opencodeNoNpm.config))
  "sops-opencode must not declare the npmrc template";
  assert check "sops-opencode/owns-opencode-template"
  (opencodeNoNpm.config.sops.templates ? "opencode-auth.json")
  "sops-opencode must still own its OpenCode template";
  assert check "sops-npmjs/disabled-absent"
  (!(hasNpmSecret npmOff.config) && !(hasNpmTemplate npmOff.config))
  "sops-npmjs with enable = false must not declare any npm artifact";
  assert check "sops-npmjs/enabled-secret" (hasNpmSecret npmOn.config)
  "sops-npmjs with enable = true must declare npmjs_auth_token";
  assert check "sops-npmjs/enabled-template" (hasNpmTemplate npmOn.config)
  "sops-npmjs with enable = true must declare the npmrc template";
  assert check "template/registry-line"
  (lib.hasInfix "registry=https://registry.yarnpkg.com" content)
  "npmrc template must set the Yarn registry";
  assert check "template/auth-line"
  (lib.hasInfix "//registry.npmjs.org/:_authToken=" content)
  "npmrc template must set the npm auth token line";
  assert check "template/uses-sops-placeholder"
  (lib.hasInfix "//registry.npmjs.org/:_authToken=${placeholder}" content)
  "npmrc template must reference the SOPS placeholder, not a value";
  assert check "template/exact-content" (content == expectedContent)
  "npmrc template must contain only the registry and placeholder auth lines; got '${content}'";
  assert check "template/no-literal-token-path"
  (!(lib.hasInfix "secrets.yaml" content))
  "npmrc template must not reference the SOPS vault file";
  assert check "source/no-readfile-npmjs"
  (!(lib.hasInfix "builtins.readFile" npmNixSource))
  "sops-npmjs must not read the secret at build time";
  assert check "source/base-no-npm"
  (!(lib.hasInfix "npmjs_auth_token" baseNixSource) && !(lib.hasInfix "npmrc" baseNixSource))
  "base sops source must not define npm artifacts";
  assert check "source/opencode-no-npm"
  (!(lib.hasInfix "npmjs_auth_token" opencodeNixSource) && !(lib.hasInfix "npmrc" opencodeNixSource))
  "sops-opencode source must not define npm artifacts";
  assert check "permissions/template-owner"
  (npmOn.config.sops.templates."npmrc".owner == "alice")
  "system npmrc template must use the configured owner";
  assert check "permissions/template-group"
  (npmOn.config.sops.templates."npmrc".group == "users")
  "system npmrc template must use the configured group";
  assert check "permissions/template-mode"
  (npmOn.config.sops.templates."npmrc".mode == "0400")
  "system npmrc template must be 0400 (or 0440 when group read is required)";
  assert check "permissions/template-not-world-readable"
  (builtins.elem npmOn.config.sops.templates."npmrc".mode ["0400" "0440"])
  "system npmrc template must not be world-readable";
  assert check "permissions/secret-mode"
  (npmOn.config.sops.secrets.npmjs_auth_token.mode == "0400")
  "system npmjs secret must use the configured least-privilege mode";
  assert check "runtime/default-path"
  (npmOn.config.sops.templates."npmrc".path == "/run/secrets/rendered/npmrc")
  "system npmrc template must default to /run/secrets/rendered/npmrc";
  pkgs.runCommand "sops-npmjs" {} ''
    echo "system sops-npmjs ownership/gating/template checks OK" > "$out"
  ''
