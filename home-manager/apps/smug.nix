{ pkgs, config, ... }:

{
  home.packages = with pkgs; [
    smug
  ];

  home.file = {
    # Solution for normies like me who are still not 100% into immutable.
    # Reference: https://www.reddit.com/r/NixOS/comments/104l0w9/comment/jhfxdq4/?utm_source=share&utm_medium=web2x&context=3
    ".config/smug" = {
        source = config.lib.file.mkOutOfStoreSymlink ~/.bookmarks/shared-configs/Wsl2_dotfiles/stow_home/smug/.config/smug;
        recursive = true;
    };
  };
}
