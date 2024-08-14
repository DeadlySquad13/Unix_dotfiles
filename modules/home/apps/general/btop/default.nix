{...}:
let
  theme-name = "deadlygruv";
in {
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
