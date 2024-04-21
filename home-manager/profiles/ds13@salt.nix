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
    ../apps/nix.nix
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
    ../apps/bash.nix
    ../apps/keepassxc.nix

    ../apps/ferdium.nix

    ../apps/zathura.nix

    ../apps/neovim.nix
    ../apps/ripgrep.nix
    # Specific.
    ../apps/qmk.nix

    ../bookmarks.nix
  ];

  programs = {
    bash.bashrcExtra = 
      ''
          # Pixi completion.
          eval "$(pixi completion --shell bash)"

          # Docker in rootless mode.
          export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
      '';
  };
}
