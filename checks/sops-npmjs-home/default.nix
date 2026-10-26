{
  pkgs,
  lib,
  namespace,
  inputs,
  ...
}: let
  # Integration check for the Home Manager side of the SOPS npm domain split
  # and the nodejs `~/.npmrc` consumer. It evaluates the REAL home `sops`,
  # `sops-npmjs`, and nodejs modules through Home Manager, then asserts
  # ownership, enable gating, template correctness, permissions, and the
  # `home.file.".npmrc"` precedence/fallback contract.
  #
  # Run:
  #   nix build --offline --impure .#checks.x86_64-linux.sops-npmjs-home

  repo = ../..;
  baseHomeSops = repo + "/modules/home/apps/ecosystem/sops/default.nix";
  homeSopsNpmjs = repo + "/modules/home/apps/ecosystem/sops-npmjs/default.nix";
  homeSopsOpencode = repo + "/modules/home/apps/ecosystem/sops-opencode/default.nix";
  nodejs = repo + "/modules/home/apps/development/nodejs/default.nix";

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

  mkHome = {
    includeNpmModule ? true,
    npmEnabled ? false,
    opencodeEnabled ? false,
    systemRuntimePath ? null,
    nodeEnabled ? true,
    explicitNpmrcSource ? null,
    fakeImplicitTemplate ? false,
  }:
    (inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      lib = libWithNamespace;
      extraSpecialArgs = {
        inherit namespace inputs;
      };
      modules =
        [
          baseHomeSops
          nodejs
          homeSopsOpencode
          homeSopsNpmjs
          {
            home.username = "alice";
            home.homeDirectory = "/home/alice";
            home.stateVersion = "24.11";
            lib.${namespace}.modules = {
              ecosystem.sops.enable = true;
              ecosystem.sops-npmjs.enable = npmEnabled;
              ecosystem.sops-opencode.enable = opencodeEnabled;
              development.nodejs.enable = nodeEnabled;
            };
          }
        ]
        ++ lib.optionals (includeNpmModule && systemRuntimePath != null) [
          {
            ${namespace}.ecosystem.sops-npmjs.systemRuntimePath = systemRuntimePath;
          }
        ]
        ++ lib.optionals (explicitNpmrcSource != null) [
          {
            ${namespace}.development.nodejs.npmrcSource = explicitNpmrcSource;
          }
        ]
        ++ lib.optionals fakeImplicitTemplate [
          (
            {
              config,
              ...
            }: {
              sops.secrets.npmjs_auth_token = {};
              sops.templates."npmrc" = {
                mode = "0400";
                content = "//registry.npmjs.org/:_authToken=${config.sops.placeholder.npmjs_auth_token}\n";
              };
            }
          )
        ];
    }).config;

  # Base home SOPS alone (sops-npmjs module absent from the graph).
  baseOnly = mkHome {
    includeNpmModule = false;
    npmEnabled = false;
  };

  # npm domain explicitly disabled (module present).
  npmOff = mkHome {
    npmEnabled = false;
  };

  # OpenCode home domain enabled, npm domain disabled.
  opencodeNoNpm = mkHome {
    npmEnabled = false;
    opencodeEnabled = true;
  };

  # npm domain enabled; Home Manager owns the template.
  npmOn = mkHome {
    npmEnabled = true;
  };

  # npm domain enabled; consume the system-rendered runtime path instead.
  npmSystem = mkHome {
    npmEnabled = true;
    systemRuntimePath = "/run/secrets/rendered/npmrc";
  };

  # Explicit nodejs.npmrcSource must win over an implicit home SOPS template.
  explicitSource = mkHome {
    npmEnabled = false;
    explicitNpmrcSource = "/explicit/npmrc";
    fakeImplicitTemplate = true;
  };

  fileOf = config: config.home.file.".npmrc";

  hasNpmSecret = config: config.sops.secrets ? "npmjs_auth_token";
  hasNpmTemplate = config: config.sops.templates ? "npmrc";

  npmContent = npmOn.sops.templates."npmrc".content;
  placeholder = npmOn.sops.placeholder.npmjs_auth_token;
  expectedContent = "registry=https://registry.yarnpkg.com\n//registry.npmjs.org/:_authToken=${placeholder}\n";

  # The consumer must be the only declarer of `home.file.".npmrc"`.
  listNix = dir:
    lib.filter
    (p: lib.hasSuffix ".nix" (toString p))
    (lib.filesystem.listFilesRecursive dir);
  npmrcDefs =
    lib.filter
    (p: lib.hasInfix "home.file.\".npmrc\"" (builtins.readFile p))
    (listNix (repo + "/modules/home") ++ listNix (repo + "/homes") ++ listNix (repo + "/systems"));

  homeSopsNpmjsSource = builtins.readFile homeSopsNpmjs;
  nodejsSource = builtins.readFile nodejs;

  sourceOut = config: toString (config.home.file.".npmrc".source);
  expectedOutOfStore = config: path: toString (config.lib.file.mkOutOfStoreSymlink path);

  check = name: cond: msg:
    if cond
    then true
    else builtins.abort "sops-npmjs-home FAIL: ${name}: ${msg}";
in
  assert check "base-sops/no-npm-secret" (!(hasNpmSecret baseOnly))
  "base home sops must not declare npmjs_auth_token";
  assert check "base-sops/no-npm-template" (!(hasNpmTemplate baseOnly))
  "base home sops must not declare the npmrc template";
  assert check "base-sops/does-not-enable-npm"
  (!(hasNpmSecret baseOnly) && !(hasNpmTemplate baseOnly))
  "enabling base home sops alone must not enable npm artifacts";
  assert check "sops-opencode/no-npm-secret" (!(hasNpmSecret opencodeNoNpm))
  "home sops-opencode must not declare npmjs_auth_token";
  assert check "sops-opencode/no-npm-template" (!(hasNpmTemplate opencodeNoNpm))
  "home sops-opencode must not declare the npmrc template";
  assert check "sops-opencode/owns-opencode-template"
  (opencodeNoNpm.sops.templates ? "opencode-auth.json")
  "home sops-opencode must still own its OpenCode template";
  assert check "sops-npmjs/disabled-absent"
  (!(hasNpmSecret npmOff) && !(hasNpmTemplate npmOff))
  "home sops-npmjs with enable = false must not declare any npm artifact";
  assert check "sops-npmjs/enabled-secret" (hasNpmSecret npmOn)
  "home sops-npmjs with enable = true must declare npmjs_auth_token";
  assert check "sops-npmjs/enabled-template" (hasNpmTemplate npmOn)
  "home sops-npmjs with enable = true must declare the npmrc template";
  assert check "template/registry-line"
  (lib.hasInfix "registry=https://registry.yarnpkg.com" npmContent)
  "home npmrc template must set the Yarn registry";
  assert check "template/auth-line"
  (lib.hasInfix "//registry.npmjs.org/:_authToken=" npmContent)
  "home npmrc template must set the npm auth token line";
  assert check "template/uses-sops-placeholder"
  (lib.hasInfix "//registry.npmjs.org/:_authToken=${placeholder}" npmContent)
  "home npmrc template must reference the SOPS placeholder, not a value";
  assert check "template/exact-content" (npmContent == expectedContent)
  "home npmrc template must contain only the registry and placeholder auth lines; got '${npmContent}'";
  assert check "template/no-literal-token-path"
  (!(lib.hasInfix "secrets.yaml" npmContent))
  "home npmrc template must not reference the SOPS vault file";
  assert check "template/no-owner-group"
  (!(npmOn.sops.templates."npmrc" ? owner) && !(npmOn.sops.templates."npmrc" ? group))
  "Home Manager sops-nix templates must not expose owner/group";
  assert check "permissions/template-mode"
  (npmOn.sops.templates."npmrc".mode == "0400")
  "home npmrc template must be mode 0400";
  assert check "permissions/template-not-world-readable"
  (npmOn.sops.templates."npmrc".mode == "0400")
  "home npmrc template must not be world-readable";
  assert check "source/no-readfile-home-npmjs"
  (!(lib.hasInfix "builtins.readFile" homeSopsNpmjsSource))
  "home sops-npmjs must not read the secret at build time";
  assert check "source/no-readfile-nodejs"
  (!(lib.hasInfix "builtins.readFile" nodejsSource))
  "nodejs consumer must not read the secret at build time";
  assert check "home-file/exactly-one-definition"
  (builtins.length npmrcDefs == 1)
  "expected exactly one home.file.\".npmrc\" definition; got ${toString (builtins.length npmrcDefs)}";
  assert check "home-file/definition-is-nodejs"
  (builtins.head npmrcDefs == nodejs)
  "the single home.file.\".npmrc\" definition must live in the nodejs consumer";
  assert check "home-file/fallback-registry-only"
  (lib.hasInfix "registry=https://registry.yarnpkg.com" (fileOf baseOnly).text)
  "with no runtime path the consumer must write a registry-only ~/.npmrc";
  assert check "home-file/fallback-has-no-token"
  (!(lib.hasInfix "_authToken=" (fileOf baseOnly).text))
  "with no runtime path the consumer must not write an auth token";
  assert check "home-file/home-template-source"
  (sourceOut npmOn == expectedOutOfStore npmOn npmOn.sops.templates."npmrc".path)
  "with a home SOPS template the consumer must symlink to the template path";
  assert check "home-file/home-template-text-null"
  ((fileOf npmOn).text == null)
  "with a home SOPS template the consumer must not inline text";
  assert check "home-file/system-path-source"
  (sourceOut npmSystem == expectedOutOfStore npmSystem "/run/secrets/rendered/npmrc")
  "with systemRuntimePath the consumer must symlink to the system runtime path";
  assert check "home-file/system-path-text-null"
  ((fileOf npmSystem).text == null)
  "with systemRuntimePath the consumer must not inline text";
  assert check "home-file/explicit-source-wins"
  (sourceOut explicitSource == expectedOutOfStore explicitSource "/explicit/npmrc")
  "an explicit nodejs.npmrcSource must win over an implicit home SOPS template";
  assert check "home-file/explicit-text-null"
  ((fileOf explicitSource).text == null)
  "an explicit npmrcSource must not inline text";
  assert check "home-file/system-path-no-home-artifacts"
  (!(hasNpmSecret npmSystem) && !(hasNpmTemplate npmSystem))
  "systemRuntimePath must avoid declaring home SOPS npm artifacts";
  assert check "sops-npmjs/system-path-wiring"
  (npmSystem.${namespace}.development.nodejs.npmrcSource == "/run/secrets/rendered/npmrc")
  "systemRuntimePath must wire nodejs.npmrcSource to the system runtime path";
  assert check "sops-npmjs/home-template-wiring"
  (npmOn.${namespace}.development.nodejs.npmrcSource == npmOn.sops.templates."npmrc".path)
  "the home sops-npmjs module must wire nodejs.npmrcSource to its template";
  pkgs.runCommand "sops-npmjs-home" {} ''
    echo "home sops-npmjs ownership/gating/template/npmrc checks OK" > "$out"
  ''
