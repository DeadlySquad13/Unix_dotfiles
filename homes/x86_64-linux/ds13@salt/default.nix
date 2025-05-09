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
}:
let
  inherit (lib.${namespace}) disabled enabled;
  in
{
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
        # config = ~/.config;
        kbd = ~/.bookmarks/kbn;
        kbn = ~/.bookmarks/kbn;
        # projects = ~/Projects;

        dotfiles = "~/.local/dotfiles-";

        # TODO: Make like in @creamsoda.
        # shared-dotfiles = "${dotfiles}/shared-";
        shared-configs = "~/.bookmarks/shared-configs";
        shared-scripts = "~/.bookmarks/shared-scripts";

        # TODO: Append home- like in @creamsoda.
        # As far as I can tell, we would need at least change paths in Ansible
        # Keyszer templates.
        home-dotfiles = "${dotfiles}";
        home-configs = "${home-dotfiles}/_configs";
        home-scripts = "${home-dotfiles}/_scripts";
      };

    modules = {
      architecturing = {
        enable = true;
      };
      cli-utility = {
        enable = true;
      };
      development = {
        enable = true;

        # FIX: Has to be enabled explicitly.
        nix = enabled;
      };
      ecosystem = {
        enable = true;
      };
      general = {
        enable = true;

        neovim = {
          enabled = true; # TODO: Remove.
          dev = true;
          stage = true;
        };

        # TODO: Repair.
        openvpn3 = disabled;
        # App works fine but it doesn't connect to server. Seems like an issue
        # with ports, systemd or something like this. Hard to investigate as logs are
        # quite lacking.
        amnezia-client = disabled;

        # MacOs Specific things.
        karabiner-elements = disabled;
        skhd = disabled;
        yabai = disabled;
      };
      gui-utility = {
        enable = true;
      };
      productivity = {
        enable = true;
      };
      misc = {
        qmk = enabled;
      };
      writing = {
        enable = true;
      };
      graphics = {
        enable = true;
      };
      tools = {
        enabled = true;

        ranger = {
          enabled = true;
          dev = true;
          stage = true;
        };
      };
      network = {
        enable = true;
      };

      bookmarks = {
        enable = true;
      };

      services = {
        enable = true;
      };
    };

    services.zapret = {
      enable = true;
    };
  };
}
