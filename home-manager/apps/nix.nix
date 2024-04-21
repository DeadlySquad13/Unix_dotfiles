{ config, pkgs, lib, ... }:

{
  nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
    settings.extra-experimental-features = [ "nix-command" "flakes" ];
  };
}
