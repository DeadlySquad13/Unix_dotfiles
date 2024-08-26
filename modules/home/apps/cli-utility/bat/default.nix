{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "cli-utility";
  name = "bat";
}
{
  programs.bat = {
    enable = true;

    config = {
      theme = "gruvbox-light";
    };
  };
}
