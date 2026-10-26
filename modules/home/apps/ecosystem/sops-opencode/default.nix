{
  config,
  lib,
  namespace,
  ...
}:
lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "ecosystem";
  name = "sops-opencode";
}
{
  sops = {
    # OpenCode-specific credentials. Generic credentials (for example
    # `npmjs_auth_token`) belong to the `sops-npmjs` domain module, not the
    # base SOPS module or `sops-opencode`. See
    # docs/adr/0008-sops-secrets-layer.md and docs/adr/0009-sops-opencode.md.
    secrets = {
      logseq_api_token = {};
      opencode_go_api_key = {};
      cheap_vibe_code_api_key = {};
      codexapi_api_key = {};
    };
    templates = {
      "logseq-mcp.env".content = ''
        LOGSEQ_API_TOKEN=${config.sops.placeholder.logseq_api_token}
      '';
      "opencode-auth.json" = {
        # Home Manager's sops-nix template module has no owner/group options;
        # activation runs as the home user. Set the mode explicitly.
        mode = "0400";
        content =
          /*
          json
          */
          ''
            {
                "opencode-go": {
                    "type": "api",
                    "key": "${config.sops.placeholder.opencode_go_api_key}"
                },
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
