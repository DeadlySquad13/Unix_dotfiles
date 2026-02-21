{
  config,
inputs,
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
    ".config/nvim".source = inputs.neovim-config-prod;
  };

  programs.bash = {
    sessionVariables = {
      EDITOR = lib.mkDefault "nvim";
      # Use neovim as a man pager.
      MANPAGER = lib.mkDefault "nvim +Man!";
    };
  };
}
