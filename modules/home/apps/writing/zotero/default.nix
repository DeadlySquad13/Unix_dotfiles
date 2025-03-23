{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "writing";
  name = "zotero";
}
{
  home.packages = with pkgs; [
    ds-omega.gl-zotero
  ];
}
