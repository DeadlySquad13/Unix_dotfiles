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
    home.file = if (config.lib.${namespace}.deploymentOptions.isDeployedFromDarwin or false) then {} else {
      # Stage.
      ".local/dotfiles-/_configs/ranger/-stage/commands.py" = lib.${namespace}.source {
        inherit config;
        get-path = p: "${p.shared-configs}/Wsl2_dotfiles/stow_home/ranger/.config/ranger/commands.py";
        out-of-store = true;
      };
      ".local/dotfiles-/_configs/ranger/-stage/rifle.conf" = lib.${namespace}.source {
        inherit config;
        get-path = p: "${p.shared-configs}/Wsl2_dotfiles/stow_home/ranger/.config/ranger/rifle.conf";
        out-of-store = true;
      };
    };

    home.shellAliases = {
      ranger-stage = "ranger --confdir=${config.home.homeDirectory}/.local/dotfiles-/_configs/ranger/-stage";
      r-stage = "ranger --confdir=${config.home.homeDirectory}/.local/dotfiles-/_configs/ranger/-stage";
    };
  }
