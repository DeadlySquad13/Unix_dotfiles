{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "development";
  name = "lazygit";
}
{
  home.file = {
    ".config/lazygit".source =
      pkgs.fetchFromGitHub {
        owner = "DeadlySquad13";
        repo = "Wsl2_dotfiles";
        rev = "d12558f1542f7aec294ed651a0b97306ec6d06ff";
        hash = "sha256-7N0ww6GnQUmlHCDSJKPb+cEUmhZXtsSWpAN8S92QwUw=";
      }
      + "/stow_home/lazygit/.config/lazygit";
  };

  home.packages = with pkgs; [
    lazygit
  ];
}
