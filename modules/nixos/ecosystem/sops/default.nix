{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "ecosystem";
  name = "sops";
}
{
  sops = {
    # # REFACTOR: Targeting root of Unix_dotfiles.
    # Read while deploying (on a system we deploy from).
    defaultSopsFile = ../../../../secrets/secrets.yaml;

    # Because we use sops on a system level for users, it should be persisted
    # and already present on a system when deploying.
    # Read on deployed system itself.
    age.keyFile = lib.mkDefault "/var/lib/sops/age/keys.txt"; # must have no password!
  };
}
