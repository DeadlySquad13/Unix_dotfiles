{
  config,
  lib,
  namespace,
  ...
}: let
  cfg = config.${namespace}.ecosystem.sops-npmjs;
in
  lib.recursiveUpdate
  (lib.${namespace}.mkIfEnabled
    {
      inherit config;
      category = "ecosystem";
      name = "sops-npmjs";
    }
    {
      # Home SOPS owns the npm token only when this home evaluates SOPS. A
      # container home sets `systemRuntimePath` and consumes the system-rendered
      # file instead. See docs/adr/0008-sops-secrets-layer.md.
      sops = lib.mkIf (cfg.systemRuntimePath == null) {
        secrets.npmjs_auth_token = {
          # Home Manager's sops-nix secret module has no owner/group options;
          # activation runs as the home user. Set the mode explicitly.
          mode = "0400";
        };
        templates."npmrc" = {
          # Home Manager's sops-nix template module has no owner/group options;
          # activation runs as the home user. Set the mode explicitly.
          mode = "0400";
          content = ''
            registry=https://registry.yarnpkg.com
            //registry.npmjs.org/:_authToken=${config.sops.placeholder.npmjs_auth_token}
          '';
        };
      };

      # The npmjs domain module is the opt-in wiring point for nodejs. An
      # explicit path set here wins over nodejs's implicit home-template
      # auto-detection.
      ${namespace}.development.nodejs.npmrcSource =
        if cfg.systemRuntimePath != null
        then cfg.systemRuntimePath
        else config.sops.templates."npmrc".path;
    })
  {
    options.${namespace}.ecosystem.sops-npmjs = {
      systemRuntimePath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Runtime path of a system-level SOPS-rendered `npmrc` for homes that
          do not evaluate Home Manager SOPS (for example darkGreen container
          homes). When null, this module declares the home SOPS secret/template
          and points nodejs at its rendered path.
        '';
      };
    };
  }
