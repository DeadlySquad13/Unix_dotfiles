{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "services";
  name = "skhd";
}
{
  services.skhd = {
    enable = true;
  };
}
