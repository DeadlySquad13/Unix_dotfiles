{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "network";
  name = "ssh";
}
{
  programs.ssh = {
    enable = true;
  };
}
