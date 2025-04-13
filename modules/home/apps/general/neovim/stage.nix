{
  lib,
  namespace,
  config,
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
    home.file = {
      # Linked it here just for uniformity. Didn't find a way to point
      # NVIM_APPNAME to it.
      ".local/dotfiles-/_configs/nvim/-stage" = lib.${namespace}.source {
        inherit config;
        get-path = p: "${p.shared-configs}/NeoVim_config";
        out-of-store = true;
      };
      ".config/nvim-stage" = lib.${namespace}.source {
        inherit config;
        get-path = p: "${p.shared-configs}/NeoVim_config";
      };
    };
    home.shellAliases = {
      nvim-stage = "NVIM_APPNAME=nvim-stage nvim";
      vi-stage = "NVIM_APPNAME=nvim-stage nvim";
    };
  }
