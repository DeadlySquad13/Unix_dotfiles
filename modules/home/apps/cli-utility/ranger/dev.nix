{
  lib,
  namespace,
  config,
  ...
}: let
  inherit (lib.ds-omega) mkIfEnabled mkIfDevEnabled;
in
  mkIfEnabled {
    inherit config;
    category = "cli-utility";
    name = "ranger";
    extraPredicate = mkIfDevEnabled;
  }
  {
    # home.file = {
    #   # Dev.
    #   ".local/dotfiles-/_configs/ranger/-dev/commands.py" = lib.${namespace}.source {
    #     inherit config;
    #     get-path = p: "${p.shared-configs}/Wsl2_dotfiles/stow_home/ranger/.config/ranger/commands.py";
    #     out-of-store = true;
    #   };
    #   ".local/dotfiles-/_configs/ranger/-dev/rifle.conf" = lib.${namespace}.source {
    #     inherit config;
    #     get-path = p: "${p.shared-configs}/Wsl2_dotfiles/stow_home/ranger/.config/ranger/rifle.conf";
    #     out-of-store = true;
    #   };
    # };

    home.shellAliases = {
      ranger-dev = "ranger --confdir=${config.home.homeDirectory}/.local/dotfiles-/_configs/ranger/-dev";
      r-dev = "ranger --confdir=${config.home.homeDirectory}/.local/dotfiles-/_configs/ranger/-dev";
    };
  }
