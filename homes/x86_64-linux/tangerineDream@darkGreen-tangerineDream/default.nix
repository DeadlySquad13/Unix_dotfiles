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

  # The system of this home config is deployed from a host different than
  # a system it will be deployed to. This home is used when deploying docker container.
  deploymentHostHome = "/home/ds13";
in {
  # REFACTOR: Implement auto-import via Snowfall-lib utils.
  # imports = [
  #   ../../../modules/home/bookmarks/darkGreen-/tangerineDream/default.nix
  # ];
  # REFACTOR: Implement auto-import via Snowfall-lib utils.
  imports = [
    ./apps/ecosystem/sops-opencode/default.nix
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
    username = "tangerineDream";
    homeDirectory = "/home/tangerineDream";
  };

  lib.${namespace} = {
    paths = rec {
      # config = /home/ds13/.config;
      kbd = /home/ds13/.bookmarks/kbn;
      kbn = /home/ds13/.bookmarks/kbn;
      projects = "${deploymentHostHome}/Projects";

      dotfiles = "${deploymentHostHome}/.local/dotfiles-";

      # TODO: Make like in @creamsoda.
      # shared-dotfiles = "${dotfiles}/shared-";
      shared-configs = "${deploymentHostHome}/.bookmarks/shared-configs";
      shared-scripts = "${deploymentHostHome}/.bookmarks/shared-scripts";

      # TODO: Append home- like in @creamsoda.
      # As far as I can tell, we would need at least change paths in Ansible
      # Keyszer templates.
      home-dotfiles = "${dotfiles}";
      home-configs = "${home-dotfiles}/_configs";
      home-scripts = "${home-dotfiles}/_scripts";
    };

    # TODO: Add as default value.
    # TODO: Move to a system level in a separate module? Why it's home
    # dependent?
    deploymentOptions = {
      isDeployedFromDarwin = false;
      isNixGlNotWorking = true;
    };

    modules = {
      ai-assistance = {
        enable = true;
      };
      architecturing = {
        enable = false;
      };
      cli-utility = {
        enable = false;

        bat = enabled;
        bash = enabled;
        zoxide = enabled;
        invoke = enabled;
        complete-alias = enabled;
        fdupes = enabled;
      };
      development = {
        enable = false;

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

        unzip = enabled;
        proxychains-ng = enabled;
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

  # FIX:Infinite recursion.
  ds-omega.ai-assistance.opencode = {
    # @ts: IOpenCodeToolOptions
    customTools = {
      pizza = false;
      zotero = false;
      taskwarrior = false;
    };
    # @ts: IOpenCodeSkillOptions
    enabledSkills = {
      logseq-db-queries = true;
    };
  };
}
