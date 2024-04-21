{ pkgs, ... }:

{
  home.file = {
    ".gitconfig".source = ~/.bookmarks/shared-configs/Wsl2_dotfiles/stow_home/git/.gitconfig;
  };

  home.packages = with pkgs; [
    git
  ];
}
