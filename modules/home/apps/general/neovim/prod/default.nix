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
    ".config/nvim" = {
      source = inputs.neovim-config-prod;
      recursive = true; # [1]
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

# References:
# [1]:
# Otherwise we get issue with some lua modules (not even talking about
# `lazy-lock.json` shenanigans):
# logseq://graph/Notes?block-id=6999d40b-0a42-499e-bb39-e0040353d5bd
