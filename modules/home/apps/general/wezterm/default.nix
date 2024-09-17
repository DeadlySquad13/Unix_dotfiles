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
    # ".config/wezterm".source = "${config.lib.${namespace}.paths.shared-configs}/WezTerm_config";
    ".config/wezterm".source = pkgs.fetchFromGitHub {
      owner = "DeadlySquad13";
      repo = "WezTerm_config";
      rev = "a62f98f6451fd678b7454a3c91cb6a27a9952915";
      hash = "sha256-BBuG5ukBp0pCkpENttevE1q2DSXy+Pg5qazbiVlQBOQ=";
    };
  };

  home.packages = with pkgs; [
    # Had some problems with package from nixpkgs in 2023.
    wezterm
  ];
}
