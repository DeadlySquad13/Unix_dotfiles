{
  lib,
  namespace,
  config,
  ...
}: let
  inherit (lib.${namespace}) mkIfEnabled mkIfDevEnabled;
in
  mkIfEnabled {
    inherit config;
    category = "cli-utility";
    name = "ranger";
    extraPredicate = mkIfDevEnabled;
  }
  {
    home.file = {
      # Dev.
      ".local/dotfiles-/_configs/ranger/-stage/commands.py" = lib.${namespace}.source {
        inherit config;
        get-path = p: "${p.shared-configs}/Wsl2_dotfiles/stow_home/ranger/.config/ranger/commands.py";
        out-of-store = false;
      };
    };

    home.shellAliases = {
      ranger-dev = "ranger --confdir=~/.local/dotfiles-/_configs/ranger/-dev";
      r-dev = "ranger --confdir=~/.local/dotfiles-/_configs/ranger/-dev";
    };
  }
