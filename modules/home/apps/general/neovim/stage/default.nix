{
  lib,
  namespace,
  config,
  pkgs,
  ...
}: let
  inherit (lib.ds-omega) mkIfEnabled mkIfStageEnabled;
in
  mkIfEnabled
  {
    inherit config;
    category = "general";
    name = "neovim";
    extraPredicate = mkIfStageEnabled;
  }
  {
    home = {
      file =
        if (config.lib.${namespace}.deploymentOptions.isDeployedFromDarwin or false)
        then {}
        else {
          # Linked it here just for uniformity. Didn't find a way to point
          # NVIM_APPNAME to it.
          ".local/dotfiles-/_configs/nvim/-stage" = lib.${namespace}.source {
            inherit config;
            get-path = p: "${p.shared-configs}/NeoVim_config";
            recursive = true;
            # out-of-store = true; # [1]
          };
          ".config/nvim-stage" = lib.${namespace}.source {
            inherit config;
            get-path = p: "${p.shared-configs}/NeoVim_config";
            recursive = true;
            # out-of-store = true; # [1]
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
# References:
# [1]:
# Otherwise we get issue with some lua modules (not even talking about
# `lazy-lock.json` shenanigans):
# logseq://graph/Notes?block-id=6999d40b-0a42-499e-bb39-e0040353d5bd
