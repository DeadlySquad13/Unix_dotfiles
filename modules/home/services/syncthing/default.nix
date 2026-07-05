{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "services";
  name = "syncthing";
}
{
  services.syncthing = {
    enable = true;
    overrideFolders = true;
    overrideDevices = true;
  };
}
