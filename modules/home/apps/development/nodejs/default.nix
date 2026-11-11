{
  lib,
  namespace,
  config,
  inputs,
  pkgs,
  ...
}: let
  cfg = config.${namespace}.development.nodejs;

  # The home-manager SOPS module is imported for every home by Snowfall, but
  # the `ecosystem.sops.npmjs` domain module only materialises the `npmrc` template on
  # homes that opt in. Look it up defensively instead of assuming
  # `config.sops.templates."npmrc"` exists.
  homeNpmrcTemplate = lib.attrByPath ["sops" "templates" "npmrc"] null config;

  # An explicit per-home/module-provided `npmrcSource` wins over an implicit
  # same-layer `ecosystem.sops.npmjs` home template. This lets a host point at a runtime
  # path rendered by *system*-level SOPS (the darkGreen images render
  # /run/secrets/rendered/npmrc) without the home template overriding it. See
  # docs/adr/0008-sops-secrets-layer.md.
  npmrcSource =
    if cfg.npmrcSource != null
    then cfg.npmrcSource
    else if homeNpmrcTemplate != null
    then homeNpmrcTemplate.path
    else null;

  base =
    lib.${namespace}.mkIfEnabled
    {
      inherit config;
      category = "development";
      name = "nodejs";
    }
    {
      home.packages = with pkgs; [
        # pkgs.node-18_x.pkgs.pnpm
        nodejs_24
        corepack_24
      ];

      # npm/npx hang against the official registry on this network, so point npm at
      # the Yarn registry mirror. The previous GitVerse mirror returned intermittent
      # HTTP 504s on cold package metadata, which npm retried with long backoff and
      # appeared as a download hang. npm reads `~/.npmrc`, which is why the config
      # lives there. Only a single `registry` is set: npm has no ordered
      # multi-registry fallback (use a caching proxy if real failover is needed).
      #
      # Only use a token-backed `npmrc` when a runtime path was explicitly
      # configured (or a home SOPS template exists). Otherwise write a
      # registry-only fallback. A plain `source = <runtime path>` would make
      # home-manager copy the decrypted file into the Nix store via
      # `builtins.path`; `mkOutOfStoreSymlink` keeps only a symlink in the store.
      home.file.".npmrc" =
        if npmrcSource != null
        then {
          source = config.lib.file.mkOutOfStoreSymlink npmrcSource;
        }
        else {
          text = ''
            registry=https://registry.yarnpkg.com
          '';
        };
    };
in
  # The option has to exist even on homes where the nodejs module is disabled,
  # because host profiles set it independently of the enable switch.
  lib.recursiveUpdate base {
    options.${namespace}.development.nodejs.npmrcSource = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Runtime path to a rendered npmrc containing the npm auth token, for
        hosts that expose the file through system-level SOPS instead of the
        home-manager SOPS module. When null (and no home SOPS template is
        available) a registry-only `~/.npmrc` is written.
      '';
    };
  }
