{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "general";
  name = "neovim";
}
{
  home.file = {
    ".config/nvim".source = pkgs.fetchFromGitHub {
      owner = "DeadlySquad13";
      repo = "NeoVim_config";
      rev = "1a5c52c46d55a266c2d2fef6b3c14c9bd533584a";
      hash = "sha256-AgPQsJqw0IrSCaivPqdaDypu76e0vzcntuBzEV+zfZo=";
    };
  };

  programs.bash = {
    sessionVariables = {
      EDITOR = "nvim";
      # Use neovim as a man pager.
      MANPAGER = "nvim +Man!";
    };
  };
}
