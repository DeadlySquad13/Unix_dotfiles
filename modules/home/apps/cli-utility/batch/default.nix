{
  pkgs,
  inputs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "cli-utility";
  name = "batch";
}
{
  # home.packages = with inputs; [
  home.packages = with pkgs; [
    ds-omega.batch
    # batch.packages.x86_64-linux.default
  ];
}
