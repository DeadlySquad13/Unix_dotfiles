{
  pkgs,
  lib,
  namespace,
  config,
  ...
}: let
  kroki-config-path = "${config.home.homeDirectory}/.config/kroki/kroki.yml";
in
  lib.${namespace}.mkIfEnabled {
    inherit config;
    category = "architecturing";
    name = "kroki-cli";
  }
  {
    home.packages = with pkgs; [
      ds-omega.kroki-cli
    ];

    programs.bash = {
      shellAliases = {
        # Diagram Create
        dc = "kroki";
      };
      sessionVariables = {
        KROKI_CONFIG = kroki-config-path;
      };
    };

    home.file = {
      ${kroki-config-path}.text = ''
        endpoint: 'http://localhost:8010'
        timeout: 5s
      '';
    };
  }
