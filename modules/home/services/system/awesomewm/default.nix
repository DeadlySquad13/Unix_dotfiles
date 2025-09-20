{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
{
  imports = [
    # Overrides next modules.
    ./dev.nix
    ./stage.nix
    ./prod.nix
  ];
}
// lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "system-services";
  name = "awesomewm";
}
{
}
