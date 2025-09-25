{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "general";
  name = "vlc";
}
{
  homebrew = {
    enable = true;
    casks = [
      "vlc"
    ];
  };
}
