{
  pkgs,
  lib,
  namespace,
  config,
  ...
}: let
  cfg = config.${namespace}.development.docker;
in {
  imports = [
    (
      lib.${namespace}.mkIfEnabled
      {
        inherit config;
        category = "development";
        name = "docker";
      }
      {
        home.packages = with pkgs;
          lib.mkIf cfg.installDocker [
            docker
          ];
        programs = {
          bash = {
            shellAliases = lib.mkIf cfg.aliasEnabled {
              d = "dockerWrapper";
            };
            bashrcExtra =
              # bash
              (lib.optionalString cfg.rootless ''
                # Docker in rootless mode.
                export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock

              '')
              + (lib.optionalString cfg.aliasEnabled ''
                # Custom autocompletion for alias.
                eval "$(docker completion bash)"

                complete -F _complete_alias d
              '');
          };
        };
      }
    )
  ];

  options.${namespace}.development.docker = {
    installDocker = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install the Docker package.";
    };

    rootless = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable rootless Docker mode.";
    };

    aliasEnabled = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable Docker alias (`d` for docker and `d c` for docker compose) and it's auto-completion.";
    };
  };
}
