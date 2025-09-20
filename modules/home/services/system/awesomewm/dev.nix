{
  lib,
  namespace,
  config,
  ...
}: let
  inherit (lib.ds-omega) mkIfEnabled mkIfDevEnabled;
in
  mkIfEnabled {
    inherit config;
    category = "system-services";
    name = "awesomewm";
    extraPredicate = mkIfDevEnabled;
  }
  {
    home.file = {
      ".config/awesome" = lib.${namespace}.source {
        inherit config;
        get-path = p: "${p.home-configs}/AwesomeWm_config";
        out-of-store = true;
      };
    };
  }
