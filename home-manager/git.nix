{ pkgs, inputs, config, ... }:

{
  programs = {
    git = {
      enable = true;
    };
    lazygit.enable = true;
  };

  home.file = {
    ".gitconfig".source = /mnt/h/Shared/Configs/Wsl2_dotfiles/stow_home/git/.gitconfig;
  };
}

