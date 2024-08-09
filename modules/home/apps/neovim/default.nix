{ pkgs, config, ... }:

# TODO: Move to programs.neovim. Use unstable channel. set .defaultEditor, .viAlias and
# .withPython3 to true.
{
  home.file = {
    # Solution for normies like me who are still not 100% into immutable.
    # Reference: https://www.reddit.com/r/NixOS/comments/104l0w9/comment/jhfxdq4/?utm_source=share&utm_medium=web2x&context=3
    ".config/nvim" = {
        source = config.lib.file.mkOutOfStoreSymlink ~/.bookmarks/shared-configs/NeoVim_config;
        recursive = true;
    };
  };

  home.packages = with pkgs; [
    # Had some problems with version from nixpkgs in 2023.
    # neovim
    xclip
  ];
  # TODO: Move all these to layer.
  imports =  
  [ 
      # Was required for rest.nvim (for luarocks to be more specific).
      ../unzip/default.nix

      # TODO: Move to a separate layer.
      ../nil/default.nix
      ../statix/default.nix
      ../alejandra/default.nix

      # TODO: Move to a separate layer.
      # Used for sniprun REPLs.
      ../deno/default.nix
  ];

  programs.bash = {
    sessionVariables = {
      # Use neovim as a man pager.
      MANPAGER = "nvim +Man!";
    };
  };
}
