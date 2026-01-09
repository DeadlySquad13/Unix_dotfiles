{
  config,
  pkgs,
  lib,
  ...
}:
# FIX: Infinite recursion when using namespace...
lib.ds-omega.mkIfEnabled
{
  inherit config;
  category = "general";
  name = "neovim";
}
{
  home.file = {
    ".config/nvim".source = pkgs.fetchFromGitHub {
      owner = "DeadlySquad13";
      repo = "NeoVim_config";
      rev = "6aeda4ea8215ce1fe0b50178e9ebd673e504e903";
      hash = "sha256-TOt19WrqopFNGZsz4m/9pCaMQ5A0y34tNxOs+7WYy3Y=";
    };
  };

  programs.bash = {
    sessionVariables = {
      EDITOR = lib.mkDefault "nvim";
      # Use neovim as a man pager.
      MANPAGER = lib.mkDefault "nvim +Man!";
    };
  };
}
