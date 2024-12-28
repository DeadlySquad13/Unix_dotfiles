{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "ecosystem";
  name = "nix";
}
{
  /* nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
    settings.extra-experimental-features = [ "nix-command" "flakes" ];
  }; */
}
