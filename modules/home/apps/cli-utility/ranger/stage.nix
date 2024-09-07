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
  category = "cli-utility";
  name = "ranger";
  extraPredicate = mkIfStageEnabled;
}
{
    home.file = {
      # Stage.
      ".local/dotfiles-/_configs/ranger/-stage/commands.py".source = ~/.bookmarks/shared-configs/Wsl2_dotfiles/stow_home/ranger/.config/ranger/commands.py;
    };

    home.shellAliases = {
      ranger-stage = "ranger --confdir=~/.local/dotfiles-/_configs/ranger/-stage";
      r-stage = "ranger --confdir=~/.local/dotfiles-/_configs/ranger/-stage";
    };
  }
