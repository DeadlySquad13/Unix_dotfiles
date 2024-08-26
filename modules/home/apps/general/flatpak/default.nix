{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "general";
  name = "flatpak";
}
{
  programs.bash = {
    sessionVariables = {
      # For flatpak
      # XDG_DATA_DIRS = "/var/lib/flatpak/exports/share:/home/ds13/.local/share/flatpak/exports/share";
    };
  };
}
