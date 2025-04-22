# TODO: Move to programs.neovim. Use unstable channel. set .defaultEditor, .viAlias and
# .withPython3 to true.
{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
{
  imports = [
    ./dev.nix
    ./stage.nix
  ];
}
// lib.${namespace}.mkIfEnabled {
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

  home.packages = with pkgs; [
    neovim
    xclip
    # REFACTOR: Required on nixos but not necessary on other systems.
    zig
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
