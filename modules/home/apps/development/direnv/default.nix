{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "development";
  name = "direnv";
}
{
  programs = {
    direnv = {
      enable = true;
      enableBashIntegration = true; # Bash should be managed by nix.
      nix-direnv.enable = true;
    };
  };
}
