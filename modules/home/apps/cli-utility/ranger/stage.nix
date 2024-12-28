{
  lib,
  namespace,
  config,
  ...
}: let
  inherit (lib.ds-omega) mkIfEnabled mkIfStageEnabled;
in
  mkIfEnabled {
    inherit config;
    category = "cli-utility";
    name = "ranger";
    extraPredicate = mkIfStageEnabled;
  }
  {
    home.file = {
      # Stage.
      ".local/dotfiles-/_configs/ranger/-stage/commands.py" = lib.${namespace}.source {
        inherit config;
        get-path = p: "${p.shared-configs}/Wsl2_dotfiles/stow_home/ranger/.config/ranger/commands.py";
        out-of-store = false;
      };
    };

    home.shellAliases = {
      ranger-stage = "ranger --confdir=~/.local/dotfiles-/_configs/ranger/-stage";
      r-stage = "ranger --confdir=~/.local/dotfiles-/_configs/ranger/-stage";
    };
  }
