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
      ".local/dotfiles-/_configs/nvim/stage-" = {
        source =  ~/.bookmarks/shared-configs/NeoVim_config;
      };
    };
    home.shellAliases = {
      nvim-stage = "nvim -u ~/.local/dotfiles-/_configs/nvim/stage-/init.vim";
      vi-stage = "nvim -u ~/.local/dotfiles-/_configs/nvim/stage-/init.vim";
    };
  }
