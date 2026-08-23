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
        cheap_vibe_code_api_key = {};
        codexapi_api_key = {};
        logseq_api_token = {};
      };
      templates = {
        "logseq-mcp.env" = {
          owner = cfg.username;
          group = "users";
          mode = "0600";
          content = "LOGSEQ_API_TOKEN=${config.sops.placeholder.logseq_api_token}";
        };
        "opencode-auth.json" = {
          owner = cfg.username;
          group = "users";
          mode = "0600";
          content =
            /*
            json
            */
            ''
              {
                  "cheapvibecode": {
                      "type": "api",
                      "key": "${config.sops.placeholder.cheap_vibe_code_api_key}"
                  }
              }
            '';
          # ''
          #   {
          #       "openai": {
          #           "type": "api",
          #           "key": "${config.sops.placeholder.codexapi_api_key}"
          #       }
          #   }
          # '';
        };
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
