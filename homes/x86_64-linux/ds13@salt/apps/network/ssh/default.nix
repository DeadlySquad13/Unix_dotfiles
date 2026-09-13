{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "network";
  name = "ssh";
}
{
  programs.ssh = {
    # Use the SSH client installed by system.
    package = null;

    # Avoid Home Manager adding global defaults, use system defaults instead.
    enableDefaultConfig = false;

    matchBlocks = {
      # TerraMaster.
      terra = {
        # INFO: Debug via `ssh -G terra | grep '^port '`
        port = 9222;
      };

      # TerraMaster in local network.
      "terra-local" = {
        # INFO: Debug via `ssh -G terra-local | grep '^port '`
        port = 9222;
      };
    };

    # INFO: In newer versions of home-manager:
    # settings = {
    #   # TerraMaster.
    #   terra.Port = 9222;
    #   # TerraMaster in local network.
    #   "terra-local".Port = 9222;
    # };

  };
}
