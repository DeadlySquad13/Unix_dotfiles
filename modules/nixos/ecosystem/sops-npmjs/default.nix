{
  lib,
  namespace,
  config,
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
      sops = {
        # npm credentials are a Node/npm concern, not an OpenCode concern. This
        # module owns only the npm domain; base SOPS settings stay in
        # `ecosystem/sops`. See docs/adr/0008-sops-secrets-layer.md.
        secrets.npmjs_auth_token = {
          owner = cfg.username;
          group = cfg.group;
          mode = cfg.mode;
        };
        templates."npmrc" = {
          owner = cfg.username;
          group = cfg.group;
          mode = cfg.mode;
          # Runtime path consumed by the darkGreen home profiles through their
          # `sops-npmjs` host glue. Home Manager is a separate module graph and
          # uses the same literal runtime path, not system `config`.
          path = cfg.runtimePath;
          content = ''
            registry=https://registry.yarnpkg.com
            //registry.npmjs.org/:_authToken=${config.sops.placeholder.npmjs_auth_token}
          '';
        };
      };
    })
  {
    options.${namespace}.ecosystem.sops-npmjs = {
      username = lib.mkOption {
        type = lib.types.str;
        description = ''
          Owner of the npmjs secret and rendered `npmrc` template. Set this in
          per-host system glue, normally to `systemBaseName`.
        '';
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "users";
        description = "Group of the npmjs secret and rendered `npmrc` template.";
      };
      mode = lib.mkOption {
        type = lib.types.str;
        default = "0400";
        description = ''
          Octal mode of the npmjs secret and rendered `npmrc` template. Keep
          least privilege (`0400`, or `0440` only when group read is required).
        '';
      };
      runtimePath = lib.mkOption {
        type = lib.types.str;
        default = "/run/secrets/rendered/npmrc";
        description = ''
          Runtime path where system-level sops-nix exposes the rendered
          `npmrc`. Home glue that does not evaluate Home Manager SOPS must use
          the same literal path.
        '';
      };
    };
  }
