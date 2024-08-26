{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "development";
  name = "docker";
}
{
  home.packages = with pkgs; [
    docker
  ];
  programs = {
    bash.bashrcExtra = 
      ''
          # Docker in rootless mode.
          export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
      '';
  };
}
