{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "services";
  name = "awesomewm";
}
{
  services.xserver = {
    enable = true;

    windowManager.awesome = {
      enable = true;
    };

    displayManager = {
      sddm.enable = true;
      defaultSession = "none+awesome";
    };
  };
}
