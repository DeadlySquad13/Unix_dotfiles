{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf;

  modules-cfg = config.lib.${namespace}.modules;
  cfg = modules-cfg.general.neovim;
in
  mkIf (cfg.enabled && cfg.stage) {
    home.file = {
      # Linked it here just for uniformity. Didn't find a way to point
      # NVIM_APPNAME to it.
      ".local/dotfiles-/_configs/nvim/-stage" = {
        source = config.lib.file.mkOutOfStoreSymlink /shared/archive-resources-/Shared/_configs/NeoVim_config;
      };
      ".config/nvim-stage" = {
        source = config.lib.file.mkOutOfStoreSymlink /shared/archive-resources-/Shared/_configs/NeoVim_config;
      };
    };
    home.shellAliases = {
      nvim-stage = "NVIM_APPNAME=nvim-stage nvim";
      vi-stage = "NVIM_APPNAME=nvim-stage nvim";
    };
  }
