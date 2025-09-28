{
  lib,
  namespace,
  config,
  pkgs,
  ...
}: let
  inherit (lib.ds-omega) mkIfEnabled mkIfStageEnabled;
in
  mkIfEnabled {
    inherit config;
    category = "general";
    name = "neovim";
    extraPredicate = mkIfStageEnabled;
  }
  {
    home = {
      file = {
        # Linked it here just for uniformity. Didn't find a way to point
        # NVIM_APPNAME to it.
        ".local/dotfiles-/_configs/nvim/-stage" = lib.${namespace}.source {
          inherit config;
          get-path = p: "${p.shared-configs}/NeoVim_config";
        };
        ".config/nvim-stage" = lib.${namespace}.source {
          inherit config;
          get-path = p: "${p.shared-configs}/NeoVim_config";
        };
      };

      packages = with pkgs; [
        ds-omega.neovim-stage
      ];

      shellAliases = {
        vi-stage = "nvim-stage";
      };
    };

    programs.bash = {
      sessionVariables = {
        EDITOR = lib.mkForce "nvim-stage";
        MANPAGER = lib.mkForce "nvim-stage +Man!";
      };
    };
  }
