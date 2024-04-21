{ config, pkgs, lib, ... }:

{
  nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
    settings.extra-experimental-features = [ "nix-command" "flakes" ];
  };
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "ds13";
  home.homeDirectory = "/home/ds13";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # neovim
    xclip
    keychain # For easier ssh keys management.

    #   Doesn't have service included. Most likely it should be enabled 'nix'
    # way.
    # udisks2

    # Utilities.
    # pkgs.wezterm
    plantuml

    # Development.
    nodejs_21
    # # Base.
    # # # Git.
    git
    lazygit
    gh # GitHub cli.
    glab # GitLab cli.

    # # # Docker.
    docker

    # # Python.
    # pixi # Package manager (only on unstable yet).

    # General.
    keepassxc

    ferdium

    zathura

    # Specific.
    qmk

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

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
    CDPATH = "~/.bookmarks:/mnt/e";
  };

  programs = {
      # Let Home Manager install and manage itself.
      home-manager.enable = true;

      direnv = {
        enable = true;
        enableBashIntegration = true; # Bash should be managed by nix.
        nix-direnv.enable = true;
      };

      bash = {
        enable = true;

        shellAliases = {
            i = "invoke --search-root ~/.bookmarks/shared-scripts";
        };

        bashrcExtra = 
        ''
            [[ -f ~/.bash/.bashrc ]] && . ~/.bash/.bashrc

            # Pixi completion.
            eval "$(pixi completion --shell bash)"

            # Docker in rootless mode.
            export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
        '';
      };
  };

  # Seems to work only on NixOs?
  # environment.etc = {
  #   nanorc = {
  #       text = ''
  #           test
  #       '';
  #   };
  # };
}
