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
    username = "terra";
    homeDirectory = "/home/terra";
  };

  lib.${namespace} = {
    # Plain paths: `terra` is a standalone non-NixOS host with no
    # runtime-home-bridge catalog, so `resolveRuntimePaths` is not used.
    # `kbd`/`kbn` are intentionally omitted.
    paths = rec {
      projects = "~/.bookmarks/projects";
      dotfiles = "~/.local/dotfiles-";

      shared-configs = "~/.bookmarks/shared-configs";
      shared-scripts = "~/.bookmarks/shared-scripts";

      home-dotfiles = "${dotfiles}";
      home-configs = "${home-dotfiles}/_configs";
      home-scripts = "${home-dotfiles}/_scripts";
    };

    deploymentOptions = {
      isDeployedFromDarwin = false;
      isNixGlNotWorking = true;
    };

    modules = {
      ai-assistance = {
        enable = false;
      };
      architecturing = {
        enable = false;
      };
      cli-utility = {
        enable = false;

        bat = enabled;
        zoxide = enabled;
        invoke = enabled;
        complete-alias = enabled;
        fdupes = enabled;
      };
      development = {
        enable = false;

        gnumake = enabled;
        git = enabled;
        lazygit = enabled;
        nodejs = enabled;
        direnv = enabled;
        nix = enabled;
      };
      ecosystem = {
        enable = false;
      };
      general = {
        enable = false;

        neovim = {
          enabled = true;
          dev = true;
          stage = false;
        };
      };
      media = {
        enable = false;
      };
      gui-utility = {
        enable = false;
      };
      productivity = {
        enable = false;
      };
      misc = {
        enable = false;
      };
      writing = {
        enable = false;
      };
      network = {
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
