{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf;

  modules-cfg = config.lib.${namespace}.modules;
  cfg = modules-cfg.tools.ranger;
in
  mkIf (cfg.enabled && cfg.dev) {
    home.file = {
      # Dev.
      ".local/dotfiles-/_configs/ranger/dev-/commands.py" = {
        source = config.lib.file.mkOutOfStoreSymlink ~/.bookmarks/shared-configs/Wsl2_dotfiles/stow_home/ranger/.config/ranger/commands.py;
      };
    };

    home.shellAliases = {
      ranger-dev = "ranger --confdir=~/.local/dotfiles-/_configs/ranger/dev-";
      r-dev = "ranger --confdir=~/.local/dotfiles-/_configs/ranger/dev-";
    };
  }
