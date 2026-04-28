{
  lib,
  namespace,
  config,
  ...
}:
{
  imports = [
    ./opencode-docker-fix.nix
  ];
}
// lib.${namespace}.mkIfEnabled
{
  inherit config;
  category = "ai-assistance";
  name = "opencode";
}
{
  programs.opencode = {
    enable = true;

    settings = {
      provider = {
        ollama = {
          npm = "@ai-sdk/openai-compatible";
          name = "Ollama (local)";
          options = {
            baseURL = "http://localhost:11434/v1";
          };
          models = {
            "qwen3.5:9b" = {
              name = "Qwen (weak)";
            };
            "qwen3.6:27b" = {
              name = "Qwen (dense)";
            };
            "qwen3.6:35b" = {
              name = "Qwen (MoE)";
            };
          };
        };
      };
    };
  };
}
