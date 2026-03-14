{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "development";
  name = "docker";
}
{
  home.packages = with pkgs; [
    docker
  ];
  programs = {
    bash = {
      shellAliases = {
        d = "dockerWrapper";
      };
      bashrcExtra =
        /*
        bash
        */
        ''
          # Docker in rootless mode.
          export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock

          # Custom autocompletion for alias.
          eval "$(docker completion bash)"

          complete -F _complete_alias d
        '';
    };
  };
}
