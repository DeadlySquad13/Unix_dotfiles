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
    username = "apakalo";
    homeDirectory = "/Users/apakalo";
  };

  lib.${namespace} = {
    paths =
      rec {
        config = ~/.config;
        kbd = ~/KnowledgeBase__Notes;
        projects = ~/Projects;

        dotfiles = "~/.local/dotfiles-";
        shared-dotfiles = "${dotfiles}/shared-";
        shared-configs = "${shared-dotfiles}/_configs";
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
        enable = true;

        mw = enabled;
        plantuml = enabled;
        drawio = enabled;
        yed = enabled;

        vue = disabled;
        inkscape = disabled;
        kroki-cli = disabled;
        # FIX: Requires alsa for some reason.
        staruml = disabled;
      };
      cli-utility = {
        enable = true;

        ranger = {
          enabled = true;
          dev = false;
          stage = false;
        };
      };
      development = {
        enable = true;

        # FIX: Has to be enabled explicitly.
        nix = enabled;

        docker = disabled;

        deno = disabled;
        browser-sync = disabled;
        zeal = disabled;
        devdocs-desktop = disabled;

        google-cloud-sdk = disabled;
      };
      ecosystem = {
        enable = true;
      };
      general = {
        enable = true;

        neovim = {
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
        syncthing = disabled;
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
        taskopen = enabled;
        taskwarrior = enabled;
        smug = enabled;

        uair = disabled;
      };
      misc = {
        qmk = disabled;
      };
      writing = {
        enable = false;
      };
    };
  };
}
