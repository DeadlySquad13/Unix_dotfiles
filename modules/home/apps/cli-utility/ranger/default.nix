{ pkgs, ... }:

{
  # As far as I can tell, I didn't do much configuration during wsl so it's
  # easier to just start over.
  # home.file = {
  #   ".config/ranger".source = ~/.bookmarks/shared-configs/Wsl2_dotfiles/stow_home/ranger/.config/ranger;
  # };

  programs.ranger = {
    enable = true;
  };
}
