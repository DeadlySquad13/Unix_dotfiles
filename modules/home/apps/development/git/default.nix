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
  name = "git";
}
{
  home.file = {
    ".gitconfig".source = ~/.bookmarks/shared-configs/Wsl2_dotfiles/stow_home/git/.gitconfig;
    ".config/git/.global_gitignore".source = ~/.bookmarks/shared-configs/Wsl2_dotfiles/stow_home/git/.global_gitignore;
  };

  home.packages = with pkgs; [
    git
  ];
}
