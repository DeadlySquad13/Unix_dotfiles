{ pkgs, ... }:

{
  # home.file = {
  #   ".config/mattermost".source = ~/.bookmarks/shared-configs/Wsl2_dotfiles/stow_home/mattermost/.config/mattermost.json;
  # };

  home.packages = with pkgs; [
    karabiner-elements
  ];
}
