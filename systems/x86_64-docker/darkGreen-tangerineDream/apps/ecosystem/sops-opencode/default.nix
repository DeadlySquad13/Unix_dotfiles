{
  lib,
  namespace,
  config,
  ...
}: let
  inherit (config.lib.${namespace}.common) spiceNamespace systemBaseName;
in
  lib.${namespace}.mkIfEnabled
  {
    inherit config;
    category = "ecosystem";
    name = "sops-opencode";
  }
  {
    sops.age.keyFile = "/usr/local/${spiceNamespace}-/${systemBaseName}/_configs/sops/age/keys.txt";
    ds-omega.ai-assistance.opencode = {
      # The username of the main user that runs opencode.
      # Used for permissions.
      username = systemBaseName;
    };
  }
