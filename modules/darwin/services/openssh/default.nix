{
  lib,
  namespace,
  config,
  ...
}: let
  inherit (lib.${namespace}) enabled;
in
  lib.${namespace}.mkIfEnabled
  {
    inherit config;
    category = "services";
    name = "openssh";
  }
  {
    # Connecting to MacOs from another machines.
    services.openssh = enabled;
  }
