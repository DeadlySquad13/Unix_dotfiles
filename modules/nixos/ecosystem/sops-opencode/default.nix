{
  lib,
  namespace,
  config,
  ...
}: let
  cfg = config.${namespace}.ai-assistance.opencode;
in
  lib.${namespace}.mkIfEnabled
  {
    inherit config;
    category = "ecosystem";
    name = "sops-opencode";
  }
  {
    sops = {
      secrets = {
        codexapi_api_key = {};
      };
      templates."opencode-auth.json" = {
        owner = cfg.username;
        group = "users";
        mode = "0600";
        content =
          /*
          json
          */
          ''
            {
                "openai": {
                    "type": "api",
                    "key": "${config.sops.placeholder.codexapi_api_key}"
                }
            }
          '';
      };
    };
  }
  // {
    options.${namespace}.ai-assistance.opencode = {
      username = lib.mkOption {
        type = lib.types.str;
        description = "The username of the main user that runs opencode. Used for permissions.";
      };
    };
  }
