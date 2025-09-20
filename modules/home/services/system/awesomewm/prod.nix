{
  lib,
  namespace,
  config,
  pkgs,
  ...
}: let
  inherit (lib.ds-omega) mkIfEnabled mkIfProdEnabled;
in
  mkIfEnabled {
    inherit config;
    category = "system-services";
    name = "awesomewm";
    # TODO: Ideally just enabling awesomewm module should enable prod version.
    # In @salt and @cake homes we shouldn't write `enabled = true` and `prod = true`
    # side by side.
    # But I'm not sure how to organize prod and dev version on one system.
    # Enable one only for testing via Xephyr?
    extraPredicate = mkIfProdEnabled;
  }
  {
    home.file = {
      ".config/awesome".source = pkgs.fetchFromGitHub {
        owner = "DeadlySquad13";
        repo = "AwesomeWm_config";
        rev = "eccb523915a965a6b2c6eacb0c6967d39bba5e67";
        hash = "sha256-0ZAthPoBncL+jxq8sUkGmLoTdrNdrGX1cO0CSCaPmJc=";
      };
    };
  }
