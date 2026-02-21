{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "productivity";
  name = "smug";
}
{
  home.packages = with pkgs; [
    smug
  ];

  home.file = {
    # Solution for normies like me who are still not 100% into immutable.
    # Reference: https://www.reddit.com/r/NixOS/comments/104l0w9/comment/jhfxdq4/?utm_source=share&utm_medium=web2x&context=3
    ".config/smug" = lib.${namespace}.source {
      inherit config;
      get-path = p: "${p.shared-configs}/Wsl2_dotfiles/stow_home/smug/.config/smug";
      out-of-store = true;
    };
  };
}
