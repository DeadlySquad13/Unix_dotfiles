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
    # Nix related.
    ../apps/home-manager.nix
    ../apps/nix.nix

    # General.
    ../apps/numlockx.nix
    ../apps/keychain.nix # For easier ssh keys management.
    ../apps/wezterm.nix
    ../apps/syncthing.nix

    #   Doesn't have service included. Most likely it should be enabled 'nix'
    # way.
    # udisks2

    # Utilities.
    # - Cli level.
    ../apps/broot.nix
    ../apps/fzf.nix
    ../apps/cht-sh.nix
    ../apps/thefuck.nix
    ../apps/bat.nix
    # - X level.
    ../apps/flameshot.nix

    # FIX: Doesn't detect gpu on Arch.
    # With yay it works, though. It also installed these packages alongside
    # maybe they were missing:
    # libdatachannel-0.20.3-2  libjuice-1.4.0-1  libsrtp-1:2.6.0-1  mbedtls-3.5.2-1  qt6-svg-6.7.0-1  rnnoise-1:0.2-1
    # ../apps/obs-studio.nix
    ../apps/vlc.nix
    ../apps/logseq.nix

    # Architecturing.
    ../apps/plantuml.nix

    # Development.
    ../apps/nodejs.nix
    ../apps/browser-sync.nix # Requires nodejs.
    ../apps/direnv.nix
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
    ../apps/telegram-desktop.nix

    ../apps/zathura.nix
    ../apps/zotero.nix

    ../apps/neovim.nix
    ../apps/ripgrep.nix
    # Specific.
    ../apps/qmk.nix

    ../bookmarks.nix
  ];

  # FIX: Doesn't seems to work.
  #
  # You can also manage environment variables but you will have to manually
  # source
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/ds13/etc/profile.d/hm-session-vars.sh
  #
  # if you don't want to manage your shell through Home Manager.
  home.sessionVariables = {
    CDPATH = "~/.bookmarks:/test";
  };

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
