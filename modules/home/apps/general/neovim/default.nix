# TODO: Move to programs.neovim. Use unstable channel. set .defaultEditor, .viAlias and
# .withPython3 to true.
{
  pkgs,
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf;

  modules-cfg = config.lib.${namespace}.modules;
  cfg = modules-cfg.general.neovim;
in
  {
    imports = [
      #./dev.nix
      #./stage.nix
    ];
  }
  // mkIf cfg.enabled {
    # home.file = {
    #   ".config/nvim".source = pkgs.fetchFromGitHub {
    #     owner = "DeadlySquad13";
    #     repo = "NeoVim_config";
    #     rev = "1a5c52c46d55a266c2d2fef6b3c14c9bd533584a";
    #     hash = "sha256-AgPQsJqw0IrSCaivPqdaDypu76e0vzcntuBzEV+zfZo=";
    #   };
    # };
    home.file = {
      # Reference: https://www.reddit.com/r/NixOS/comments/104l0w9/comment/jhfxdq4/?utm_source=share&utm_medium=web2x&context=3
      ".config/nvim" = {
        source = config.lib.file.mkOutOfStoreSymlink ~/.local/dotfiles-/shared-/_configs/NeoVim_config;
        recursive = true;
      };
   };

    home.packages = with pkgs; [
      # Had some problems with version from nixpkgs in 2023.
      # neovim
      xclip
    ];
    # TODO: Move all these to layer.
    # imports =
    # [
    #     # Was required for rest.nvim (for luarocks to be more specific).
    #     ../unzip/default.nix

    #     # TODO: Move to a separate layer.
    #     ../nil/default.nix
    #     ../statix/default.nix
    #     ../alejandra/default.nix

    #     # TODO: Move to a separate layer.
    #     # Used for sniprun REPLs.
    #     ../deno/default.nix
    # ];

    programs.bash = {
      sessionVariables = {
        # Use neovim as a man pager.
        MANPAGER = "nvim +Man!";
      };
    };
  }
