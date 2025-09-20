{
  lib,
  namespace,
  config,
  ...
}: let
  inherit (lib.ds-omega) mkIfEnabled mkIfStageEnabled;
in
  mkIfEnabled {
    inherit config;
    # REFACTOR: Naming
    category = "system-services";
    name = "awesomewm";
    extraPredicate = mkIfStageEnabled;
  }
  {
    home.file = {
      ".config/awesome" = lib.${namespace}.source {
        inherit config;
        get-path = p: "${p.home-configs}/AwesomeWm_config";
      };
    };
  }
