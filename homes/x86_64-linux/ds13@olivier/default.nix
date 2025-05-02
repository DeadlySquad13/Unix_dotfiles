{
  # Snowfall Lib provides a customized `lib` instance with access to your flake's library
  # as well as the libraries available from your flake's inputs.
  lib,
  # An instance of `pkgs` with your overlays and packages applied is also available.
  pkgs,
  # You also have access to your flake's inputs.
  inputs,
  # Additional metadata is provided by Snowfall Lib.
  namespace, # The namespace used for your flake, defaulting to "internal" if not set.
  home, # The home architecture for this host (eg. `x86_64-linux`).
  target, # The Snowfall Lib target for this home (eg. `x86_64-home`).
  format, # A normalized name for the home target (eg. `home`).
  virtual, # A boolean to determine whether this home is a virtual target using nixos-generators.
  host, # The host name for this home.
  # All other arguments come from the home home.
  config,
  ...
}: let
  inherit (lib.${namespace}) disabled enabled;
in {
  home = {
    # This value determines the Home Manager release that your configuration is
    # compatible with. This helps avoid breakage when a new Home Manager release
    # introduces backwards incompatible changes.
    #
    # You should not change this value, even if you update Home Manager. If you do
    # want to update the value, then make sure to first check the Home Manager
    # release notes.
    stateVersion = "24.11";
    # Home Manager needs a bit of information about you and the paths it should
    # manage.
    username = "ds13";
    homeDirectory = "/home/ds13";
  };

  lib.${namespace} = {
    paths =
      rec {
        config = ~/.config;
        kbd = /mnt/h/Resources/KnowledgeBase__Notes;
        projects = ~/Projects;

        dotfiles = "/mnt/h";
        shared-dotfiles = "${dotfiles}/Shared";
        shared-configs = "${shared-dotfiles}/Configs";
        shared-scripts = "${shared-dotfiles}/_scripts";

        home-dotfiles = "${dotfiles}/home-";
        home-configs = "${home-dotfiles}/_configs";
        home-scripts = "${home-dotfiles}/_scripts";
      }
      //
      # More specific.
      # # Projects
      builtins.mapAttrs (name: value: "/Users/apakalo/Projects/${value}") {
        # Namespaces.
        "ephemeral-projects" = "ephemeral-";
        "interim-projects" = "interim-";
      };
    modules = {
      architecturing = {
        enable = false;
      };
      cli-utility = {
        enable = false;

        bat = enabled;
        bash = enabled;
        zoxide = enabled;
        complete-alias = enabled;
      };
      development = {
        enable = false;

        git = enabled;
        lazygit = enabled;
        nodejs = enabled;
        direnv = enabled;
        pixi = disabled;
        gh = enabled;
        nix = enabled;
      };
      ecosystem = {
        enable = false;
      };
      general = {
        enable = true;

        neovim = {
          enabled = true; # TODO: Remove.
          dev = true;
          stage = false;
        };

        keepassxc = disabled;
        ferdium = disabled;
        telegram-desktop = disabled;
        zathura = disabled;

        wireguard-tools = disabled;
        unzip = disabled;
        vlc = disabled;
        keychain = disabled;
        numlockx = disabled;
        obs-studio = disabled;
        qbittorrent = disabled;
        syncthing = enabled;
        btop = disabled;
        flatpak = disabled;
        java-fonts-fix = disabled;
        openvpn3 = disabled;
        gpick = disabled;
      };
      gui-utility = {
        enable = false;
      };
      productivity = {
        enable = false;

        taskwarrior = enabled;
      };
      misc = {
        qmk = enabled;
      };
      writing = {
        enable = false;
      };

      tools = {
        enabled = false;

        ranger = {
          enabled = false;
          dev = false;
          stage = false;
        };
      };
    };
  };
}
