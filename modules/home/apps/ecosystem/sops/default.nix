{
  pkgs,
  lib,
  namespace,
  config,
  inputs,
  ...
}:
{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];
}
// lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "ecosystem";
  name = "sops";
}
{
  home.packages = with pkgs; [
    # Used for generating age file `age-keygen`.
    age
  ];

  sops = {
    # This is using an age key that is expected to already be in the filesystem
    age.keyFile = lib.mkDefault "${config.home.homeDirectory}/.config/sops/age/keys.txt"; # must have no password!
    # REFACTOR: Targeting root of Unix_dotfiles.
    defaultSopsFile = ../../../../../secrets/secrets.yaml;
    secrets = {
      glab_DeadlySquad13_token = {
        #   sopsFile = ../../../../../secrets/secrets.yaml; # optionally define per-secret files

        #   # %r gets replaced with a runtime directory, use %% to specify a '%'
        #   # sign. Runtime dir is $XDG_RUNTIME_DIR on linux and $(getconf
        #   # DARWIN_USER_TEMP_DIR) on darwin.
        # path = "%r/test.txt";
      };
      yandex_disk_username = {};
      yandex_disk_password = {};
      codexapi_api_key = {};
      cheap_vibe_code_api_key = {};
    };
    templates."opencode-auth.json" = {
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
        #     "openai": {
        #       "type": "api",
        #       "key": "${config.sops.placeholder.codexapi_api_key}"
        #     }
        #   }
        # '';
    };
  };
}
