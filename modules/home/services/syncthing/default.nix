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
  extraPredicate = lib.${namespace}.isLinux;
}
{
  services.syncthing = {
    enable = true;
    overrideFolders = true;
    overrideDevices = true;
  };
}
