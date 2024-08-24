{
  lib,
  namespace,
  config,
  ...
}: let
  theme-name = "deadlygruv";
in
  lib.${namespace}.mkIfEnabled {
    inherit config;
    category = "general";
    name = "btop";
  }
  {
    programs.btop = {
      enable = true;

      settings = {
        color_theme = theme-name;
        theme_background = false;
      };
    };

    home.file = {
      ".config/btop/themes/${theme-name}.theme".source = ./${theme-name}.theme;
    };
  }
