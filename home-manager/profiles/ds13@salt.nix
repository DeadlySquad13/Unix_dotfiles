{ config, lib, ... }:

{
  home.stateVersion = "23.05";
  imports =  
  [ 
    ../apps/ripgrep.nix
    ../bookmarks.nix
  ];

  home.file = {
    # Solution for normies like me who are still not 100% into immutable.
    # Reference: https://www.reddit.com/r/NixOS/comments/104l0w9/comment/jhfxdq4/?utm_source=share&utm_medium=web2x&context=3
    ".config/nvim" = {
        source = config.lib.file.mkOutOfStoreSymlink ~/.bookmarks/shared-configs/NeoVim_config;
        recursive = true;
    };

    # # xdg home should be set to "$HOME/.config", otherwise wezterm will look
    # in another location.
    ".config/wezterm".source = ~/.bookmarks/shared-configs/WezTerm_config;

    ".bash".source = ~/.bookmarks/shared-configs/Bash_config;

    ".gitconfig".source = ~/.bookmarks/shared-configs/Wsl2_dotfiles/stow_home/git/.gitconfig;
    ".config/lazygit".source = ~/.bookmarks/shared-configs/Wsl2_dotfiles/stow_home/lazygit/.config/lazygit;

    # Not working unfortunately... It seems that left part can't start with '/'.
    # "/usr/local/share/fonts/Iosevka".source = ~/.bookmarks/shared-fonts;
    
    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };
}
