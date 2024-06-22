{ pkgs, ... }:

{
  home.file = {
    ".config/ranger".source = ~/.bookmarks/shared-configs/Wsl2_dotfiles/stow_home/ranger/.config/ranger;
  };

  home.packages = with pkgs; [
    ranger
  ];
}
