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
  category = "cli-utility";
  name = "ranger";
  extraPredicate = mkIfDevEnabled;
}
{
  home.file = {
    # Dev.
    ".local/dotfiles-/_configs/ranger/-dev/commands.py" = {
      source = config.lib.file.mkOutOfStoreSymlink ~/.bookmarks/shared-configs/Wsl2_dotfiles/stow_home/ranger/.config/ranger/commands.py;
    };
  };

  home.shellAliases = {
    ranger-dev = "ranger --confdir=~/.local/dotfiles-/_configs/ranger/-dev";
    r-dev = "ranger --confdir=~/.local/dotfiles-/_configs/ranger/-dev";
  };
}
