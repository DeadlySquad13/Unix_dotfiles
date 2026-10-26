{
  lib,
  namespace,
  config,
  ...
}: let
  inherit (config.lib.${namespace}.common) systemBaseName;
in
  lib.${namespace}.mkIfEnabled
  {
    inherit config;
    category = "ecosystem";
    name = "sops-npmjs";
  }
  {
    # System-to-home mapping: the home profile
    # `homes/x86_64-linux/tangerineDream@darkGreen-tangerineDream/apps/ecosystem/sops-npmjs`
    # consumes this exact runtime path literally because Home Manager is a
    # separate module graph and must not read system `config`.
    ${namespace}.ecosystem.sops-npmjs = {
      username = systemBaseName;
      group = "users";
      mode = "0400";
      runtimePath = "/run/secrets/rendered/npmrc";
    };
  }
