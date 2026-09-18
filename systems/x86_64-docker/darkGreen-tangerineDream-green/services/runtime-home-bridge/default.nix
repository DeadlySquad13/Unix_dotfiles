{
  lib,
  namespace,
  config,
  ...
}: let
  inherit (config.lib.${namespace}.common) systemBaseName;
  inherit (config.users.users.${systemBaseName}) home;
  catalog = lib.${namespace}.catalogs.darkGreen-tangerineDream-green;
in
  lib.${namespace}.mkIfEnabled
  {
    inherit config;
    category = "services";
    name = "runtime-home-bridge";
  }
  {
    services.runtime-home-bridge = {
      user = systemBaseName;
      homeDirectory = home;
      inherit (catalog) namespaceRoot zNamespaceRoot variants;
      required = true;
      # Full catalog artifact, host-readable via the compose bind mount
      # /zsalt/var-/<systemBaseName>@<containerUserName>/share/runtime-home-bridge
      # (see the @tangerineDream docker-compose repo).
      catalogArtifactPath = "${catalog.zNamespaceRoot}/share/runtime-home-bridge/catalog.json";
    };
  }
