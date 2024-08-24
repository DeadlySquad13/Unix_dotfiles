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
  mkIf (cfg.enabled && cfg.dev) {
    home.file = {
      # Reference: https://www.reddit.com/r/NixOS/comments/104l0w9/comment/jhfxdq4/?utm_source=share&utm_medium=web2x&context=3

      # Linked it here just for uniformity. Didn't find a way to point
      # NVIM_APPNAME to it.
      ".local/dotfiles-/_configs/nvim/-dev" = {
        source = config.lib.file.mkOutOfStoreSymlink /shared/archive-resources-/Shared/_configs/NeoVim_config;
        recursive = true;
      };
      ".config/nvim-dev" = {
        source = config.lib.file.mkOutOfStoreSymlink /shared/archive-resources-/Shared/_configs/NeoVim_config;
        recursive = true;
      };
    };
    home.shellAliases = {
      nvim-dev = "NVIM_APPNAME=nvim-dev nvim";
      vi-dev = "NVIM_APPNAME=nvim-dev nvim";
    };
  }
