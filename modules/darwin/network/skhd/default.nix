{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "network";
  name = "deskflow";
}
{
  homebrew = {
    enable = true;
    taps = [
      "deskflow/homebrew-tap"
    ];
    casks = [
      "deskflow"
    ];
  };
}
