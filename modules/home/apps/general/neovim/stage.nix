{
  lib,
  namespace,
  config,
  ...
}:
let
  inherit (lib.${namespace}) mkIfEnabled mkIfStageEnabled;
in mkIfEnabled {
  inherit config;
  category = "general";
  name = "neovim";
  extraPredicate = mkIfStageEnabled;
}
{
    home.file = {
      # Linked it here just for uniformity. Didn't find a way to point
      # NVIM_APPNAME to it.
      ".local/dotfiles-/_configs/nvim/-stage" = {
        source = /shared/archive-resources-/Shared/_configs/NeoVim_config;
      };
      ".config/nvim-stage" = {
        source = /shared/archive-resources-/Shared/_configs/NeoVim_config;
      };
    };
    home.shellAliases = {
      nvim-stage = "NVIM_APPNAME=nvim-stage nvim";
      vi-stage = "NVIM_APPNAME=nvim-stage nvim";
    };
  }
