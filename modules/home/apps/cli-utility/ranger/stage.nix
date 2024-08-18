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
  mkIf (cfg.enabled
    && cfg.stage) {
    home.file = {
      # Stage.
      ".local/dotfiles-/_configs/ranger/stage-/commands.py".source = ~/.bookmarks/shared-configs/Wsl2_dotfiles/stow_home/ranger/.config/ranger/commands.py;
    };

    home.shellAliases = {
      ranger-stage = "ranger --confdir=~/.local/dotfiles-/_configs/ranger/stage-";
      r-stage = "ranger --confdir=~/.local/dotfiles-/_configs/ranger/stage-";
    };
  }
