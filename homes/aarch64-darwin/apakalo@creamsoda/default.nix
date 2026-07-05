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
  inherit (lib.ds-omega) disabled enabled;
in {
  imports = [
    ./syncthing/default.nix
  ];

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

  lib.ds-omega = {
    paths =
      rec {
        config = ~/.config;
        kbd = ~/KnowledgeBase__Notes;
        projects = ~/Projects;

        # These are used for symlinks and they need to be strings according to
        # our `lib.ds-omega.source` interface.

        shared-projects = "~/Projects/shared-";

        dotfiles = "~/.local/dotfiles-";
        # "System" in a sense of inheritance by other homes. It's still limited
        # to home-manager.
        system-dotfiles = "${dotfiles}/shared-";
        system-configs = "${system-dotfiles}/_configs";
        system-scripts = "${system-dotfiles}/_scripts";

        # Left for compatibility reasons. On @salt and @olivier, it points to
        # locations, shared between dual-boot systems.
        # @deprecated.
        shared-dotfiles = system-dotfiles;
        # @deprecated.
        shared-configs = system-configs;
        # @deprecated.
        shared-scripts = system-scripts;

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
      ai-assistance = {
        enable = true;
      };
      architecturing = {
        enable = true;

        mw = enabled;
        plantuml = enabled;
        drawio = enabled;
        yed = enabled;
        kroki-cli = enabled;

        vue = disabled;
        inkscape = disabled;
        # FIX: Requires alsa for some reason.
        staruml = disabled;
      };
      cli-utility = {
        enable = true;

        ranger = {
          enabled = true;
          dev = true;
          stage = true;
        };
      };
      development = {
        enable = true;

        # FIX: Has to be enabled explicitly.
        nix = enabled;

        docker = enabled;

        deno = disabled;
        browser-sync = disabled;

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

        element-desktop = disabled;
        keepassxc = disabled;
        ferdium = disabled;
        telegram-desktop = disabled;
        zathura = disabled;
        anki = disabled;
        musescore = disabled;

        wireguard-tools = disabled;
        unzip = disabled;
        keychain = disabled;
        numlockx = disabled;
        obs-studio = disabled; # enabled; # For demo recordings.
        qbittorrent = disabled;
        syncthing = enabled;
        btop = disabled;
        flatpak = disabled;
        java-fonts-fix = disabled;
        gpick = disabled;
      };
      media = {
        enable = false;
      };
      gui-utility = {
        enable = false;
      };
      productivity = {
        taskopen = enabled;
        # FIX: Has to be enabled explicitly.
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
      network = {
        enable = false;

        # TODO: Repair.
        openvpn3 = disabled;
      };

      bookmarks = {
        enable = true;
      };

      services = {
        enable = false;

        syncthing = enabled;
      };
    };
  };

  # FIX: For some reason on Darwin can't use `${namespace}`: infinite
  # recursion.
  ds-omega.development.docker = {
    installDockerPackage = false; # Already installed by provider.
    rootless = false;
    enableAlias = true;
  };
}
