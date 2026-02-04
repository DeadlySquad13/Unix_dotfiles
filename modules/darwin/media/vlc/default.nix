{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "media";
  name = "vlc";
}
{
  # REFACTOR: Vlc into separate profile (non-working).
  homebrew = {
    enable = true;
    casks = [
      "vlc"
    ];
  };
}
