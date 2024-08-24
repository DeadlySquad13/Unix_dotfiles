{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "ecosystem";
  name = "home-manager";
}
{
  programs = {
    # Let Home Manager install and manage itself.
    home-manager.enable = true;
  };
}
