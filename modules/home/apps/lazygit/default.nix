{ pkgs, ... }:

{
  home.file = {
    ".config/lazygit".source = ~/.bookmarks/shared-configs/Wsl2_dotfiles/stow_home/lazygit/.config/lazygit;
  };

  home.packages = with pkgs; [
    lazygit
  ];
}
