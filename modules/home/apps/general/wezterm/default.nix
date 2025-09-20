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
    # TODO: Add dev and stage versions.
    ".config/wezterm" = lib.${namespace}.source {
      inherit config;
      get-path = p: "${p.shared-configs}/Wezterm_config";
      out-of-store = true;
    };

    # ".config/wezterm".source = pkgs.fetchFromGitHub {
    #   owner = "DeadlySquad13";
    #   repo = "WezTerm_config";
    #   rev = "d27f692904fea31ffdb1a457e7f9117f2eb02099";
    #   hash = "sha256-Vzow3+EzU21VczWEjzMSEXcOL/DGzA2N8q7mySjpqTA=";
    # };
  };

  home.packages = with pkgs; [
    # wezterm
  ];
}
