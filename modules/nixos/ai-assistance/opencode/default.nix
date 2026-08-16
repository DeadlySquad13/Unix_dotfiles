{
  lib,
  config,
  namespace,
  ...
}: let
  inherit (lib.${namespace}) source;
  cfg = config.${namespace}.ai-assistance.opencode;
in
  lib.${namespace}.mkIfEnabled
  {
    inherit config;
    category = "ai-assistance";
    name = "opencode";
  }
  {
    # Sops template is not guaranteed to exist in nix store during build so
    # we're symlinking to it's predetermined location: it will be available
    # once program is run.
    # TODO: name
    home-manager.users.${cfg.username} = {config, ...}: {
      home.file.".local/share/opencode/auth.json" = lib.mkDefault (source {
        inherit config;
        # get-path = _p: config.sops.templates."opencode-auth.json".path;
        get-path = _p: "/run/secrets/rendered/opencode-auth.json";
        out-of-store = true;
      });
    };
  }
