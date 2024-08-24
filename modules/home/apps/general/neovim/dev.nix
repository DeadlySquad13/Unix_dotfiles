{
  lib,
  namespace,
  config,
  ...
}:
let
  inherit (lib.${namespace}) mkIfEnabled mkIfDevEnabled;
in mkIfEnabled {
  inherit config;
  category = "general";
  name = "neovim";
  extraPredicate = mkIfDevEnabled;
}
{
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
