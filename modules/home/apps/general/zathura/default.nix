{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "general";
  name = "zathura";
}
{
  programs.zathura = {
    enable = true;

    options = {
      default-bg = "#EDE2CC";
      selection-clipboard = "clipboard";
    };

    mappings = {
      d = "scroll down";
      u = "scroll up";

      # Scroll by pages.
      n = "navigate next";
      e = "navigate previous";

      # Toggle between one-page and multi-page modes.
      D = "toggle_page_mode";

      "<Tab>" = "search forward";
      # Doesn't work unfortunately, use <S-n> instead.
      "<S-Tab>" = "search backward";

      i = "toggle_index";
    };
  };
}
