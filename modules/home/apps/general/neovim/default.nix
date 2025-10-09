# TODO: Move to programs.neovim. Set .defaultEditor, .viAlias and
# .withPython3 to true.
{
  pkgs,
  lib,
  namespace,
  config,
  ...
}: let
  inherit (lib.ds-omega) mkIfLinux;
  inherit (lib) mkIf mkMerge;
in
  {
    imports = [
      # Overrides next modules.
      ./dev.nix
      ./stage.nix
      ./prod.nix
    ];
  }
  // lib.${namespace}.mkIfEnabled
  {
    inherit config;
    category = "general";
    name = "neovim";
  }
  {
    home = mkMerge [
      {
        packages = with pkgs; [
          neovim
          # REFACTOR: *Required* on nixos but not necessary on other systems.
          zig
        ];
      }
      (mkIf (mkIfLinux {}) {
        packages = with pkgs; [
          xclip
        ];
      })
    ];
    # (
    #     mkIf (mkIfLinux {}) [
    #       xclip
    #       zig
    #     ]
    #   )
    # );
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
  }
