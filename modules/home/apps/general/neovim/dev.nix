{
  lib,
  namespace,
  config,
  pkgs,
  ...
}: let
  inherit (lib.ds-omega) mkIfEnabled mkIfDevEnabled;
in
  mkIfEnabled {
    inherit config;
    category = "general";
    name = "neovim";
    extraPredicate = mkIfDevEnabled;
  }
  {
    home = {
    #   file = {
    #     # Reference: https://www.reddit.com/r/NixOS/comments/104l0w9/comment/jhfxdq4/?utm_source=share&utm_medium=web2x&context=3

    #     # Linked it here just for uniformity. Didn't find a way to point
    #     # NVIM_APPNAME to it.
    #     # STYLE: on Linux it's just this but on Unix it's
    #     # ...dotfiles-/shared-/_configs...
    #     ".local/dotfiles-/_configs/nvim/-dev" = lib.${namespace}.source {
    #       inherit config;
    #       get-path = p: "${p.shared-configs}/NeoVim_config";
    #       out-of-store = true;
    #     };
    #     ".config/nvim-dev" = lib.${namespace}.source {
    #       inherit config;
    #       get-path = p: "${p.shared-configs}/NeoVim_config";
    #       out-of-store = true;
    #     };
    #   };

      # packages = with pkgs; [
      #   ds-omega.neovim-dev
      # ];

      shellAliases = {
        vi-dev = "nvim-dev";
      };
    };

    programs.bash = {
      sessionVariables = {
        EDITOR = "nvim-dev";
        MANPAGER = "nvim-dev +Man!";
      };
    };
  }
