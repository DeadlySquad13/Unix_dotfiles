{ config, pkgs, lib, ... }:

{
  nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
    settings.extra-experimental-features = [ "nix-command" "flakes" ];
  };

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [

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
