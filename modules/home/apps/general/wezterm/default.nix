{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "general";
  name = "wezterm";
}
{
  home.file = {
    # # xdg home should be set to "$HOME/.config", otherwise wezterm will look
    # in another location.
    ".config/wezterm".source = ~/.bookmarks/shared-configs/WezTerm_config;
  };

  home.packages = with pkgs; [
    # Had some problems with package from nixpkgs in 2023.
    # wezterm
  ];
}
