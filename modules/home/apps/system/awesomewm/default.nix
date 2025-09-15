{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "system";
  name = "awesomewm";
}
{
  home = {
    file = {
      ".config/awesome" = lib.${namespace}.source {
        inherit config;
        get-path = p: "${p.home-configs}/AwesomeWm_config";
        out-of-store = true;
      };
    };
  };
}
