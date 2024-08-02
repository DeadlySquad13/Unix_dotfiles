{ pkgs, ... }:

{
  home.file = {
    ".config/mattermost".source = ~/.bookmarks/shared-configs/Wsl2_dotfiles/stow_home/mattermost/.config/mattermost;
  };

  home.packages = with pkgs; [
    mattermost
  ];
}
