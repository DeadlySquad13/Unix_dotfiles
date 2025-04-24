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
  name = "proxychains-ng";
}
{
  home.packages = with pkgs; [
    proxychains-ng
  ];

  home.file = {
    ".proxychains/proxychains.conf".source = ./proxychains.conf;
  };
}
