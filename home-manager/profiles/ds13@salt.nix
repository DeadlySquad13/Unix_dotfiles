{ config, lib, ... }:

{
  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.05";
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "ds13";
  home.homeDirectory = "/home/ds13";

  imports =  
  [ 
    ../apps/keychain.nix # For easier ssh keys management.

    #   Doesn't have service included. Most likely it should be enabled 'nix'
    # way.
    # udisks2

    # Utilities.
    ../apps/wezterm.nix
    ../apps/plantuml.nix

    # Development.
    ../apps/nodejs.nix
    # # Base.
    # # # Git.
    ../apps/git.nix
    ../apps/lazygit.nix
    ../apps/gh.nix # GitHub cli.
    ../apps/glab.nix # GitLab cli.

    # # # Docker.
    ../apps/docker.nix

    # # Python.
    # pixi # Package manager (only on unstable yet).

    # General.
    ../apps/keepassxc.nix

    ../apps/ferdium.nix

    ../apps/zathura.nix

    ../apps/neovim.nix
    ../apps/ripgrep.nix
    # Specific.
    ../apps/qmk.nix

    ../bookmarks.nix
  ];

  home.file = {
    ".bash".source = ~/.bookmarks/shared-configs/Bash_config;

    # Not working unfortunately... It seems that left part can't start with '/'.
    # "/usr/local/share/fonts/Iosevka".source = ~/.bookmarks/shared-fonts;
    
    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };
}
