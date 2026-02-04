{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "media.audio";
  name = "strawberry";
}
{
  home.packages = with pkgs; [
    strawberry
  ];
}
