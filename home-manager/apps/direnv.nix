{ config, pkgs, lib, ... }:

{
  programs = {
    direnv = {
      enable = true;
      enableBashIntegration = true; # Bash should be managed by nix.
      nix-direnv.enable = true;
    };
  };
}
