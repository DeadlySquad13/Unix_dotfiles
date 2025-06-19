{
  pkgs,
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
  home.file = {
    # Prod.
    ".config/awesome".source = pkgs.fetchFromGitHub {
      owner = "DeadlySquad13";
      repo = "AwesomeWm_config";
      rev = "eccb523915a965a6b2c6eacb0c6967d39bba5e67";
      hash = "sha256-0ZAthPoBncL+jxq8sUkGmLoTdrNdrGX1cO0CSCaPmJc=";
    };
  };
}
