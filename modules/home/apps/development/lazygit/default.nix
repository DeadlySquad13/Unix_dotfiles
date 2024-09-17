{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
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
          rev = "af728d9f05f25656ab8fcefa66d767c5b558710e";
          hash = "sha256-3hT3Gzh7vDRap1prJFyu+av4SS0kbu+HVYPbHRYw0YE=";
        }
        + "/stow_home/lazygit/.config/lazygit";
  };

  home.packages = with pkgs; [
    lazygit
  ];
}
