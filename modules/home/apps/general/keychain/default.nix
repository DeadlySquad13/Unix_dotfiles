{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "general";
  name = "keychain";
}
{
  home.packages = with pkgs; [
    keychain
  ];
}
