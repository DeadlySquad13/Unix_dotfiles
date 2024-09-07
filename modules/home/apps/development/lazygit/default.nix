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
  name = "lazygit";
}
{
  home.file = {
    ".config/lazygit".source = ~/.bookmarks/shared-configs/Wsl2_dotfiles/stow_home/lazygit/.config/lazygit;
  };

  home.packages = with pkgs; [
    lazygit
  ];
}
