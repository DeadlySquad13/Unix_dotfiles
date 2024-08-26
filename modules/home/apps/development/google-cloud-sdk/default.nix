{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "development";
  name = "google-cloud-sdk";
}
{
  home.packages = with pkgs; [
    google-cloud-sdk
  ];
}
