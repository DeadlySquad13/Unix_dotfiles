{
  lib,
  config,
  ...
}:
# FIX: Infinite recursion (only when building dockerConfigurations).
lib.ds-omega.mkIfEnabled
{
  inherit config;
  category = "ai-assistance";
  name = "opencode";
}
{
  programs.opencode.settings = {
    small_model = "cheapvibecode/deepseek-v4-flash";
    provider.cheapvibecode = {
      npm = "@ai-sdk/openai-compatible";
      name = "CheapVibeCode";
      options = {
        baseURL = "https://cheapvibecode.ru/v1";
      };
      models = {
        "gpt-5.6-sol" = {
          name = "GPT 5.6 Sol";
          modalities = {
            input = [
              "text"
              "image"
              "pdf"
            ];
            output = [
              "text"
            ];
          };
          attachment = true;
          reasoning = true;
          temperature = false;
          tool_call = true;
          limit = {
            context = 353000;
            input = 225000;
            output = 128000;
          };
          variants = {
            none = {
              reasoningEffort = "none";
            };
            low = {
              reasoningEffort = "low";
            };
            medium = {
              reasoningEffort = "medium";
            };
            high = {
              reasoningEffort = "high";
            };
            xhigh = {
              reasoningEffort = "xhigh";
            };
            max = {
              reasoningEffort = "max";
            };
          };
        };
        "gpt-5.6-terra" = {
          name = "GPT 5.6 Terra";
          modalities = {
            input = [
              "text"
              "image"
              "pdf"
            ];
            output = [
              "text"
            ];
          };
          attachment = true;
          reasoning = true;
          temperature = false;
          tool_call = true;
          limit = {
            context = 353000;
            input = 225000;
            output = 128000;
          };
          variants = {
            none = {
              reasoningEffort = "none";
            };
            low = {
              reasoningEffort = "low";
            };
            medium = {
              reasoningEffort = "medium";
            };
            high = {
              reasoningEffort = "high";
            };
            xhigh = {
              reasoningEffort = "xhigh";
            };
            max = {
              reasoningEffort = "max";
            };
          };
        };
        "gpt-5.6-luna" = {
          name = "GPT 5.6 Luna";
          modalities = {
            input = [
              "text"
              "image"
              "pdf"
            ];
            output = [
              "text"
            ];
          };
          attachment = true;
          reasoning = true;
          temperature = false;
          tool_call = true;
          limit = {
            context = 353000;
            input = 225000;
            output = 128000;
          };
          variants = {
            none = {
              reasoningEffort = "none";
            };
            low = {
              reasoningEffort = "low";
            };
            medium = {
              reasoningEffort = "medium";
            };
            high = {
              reasoningEffort = "high";
            };
            xhigh = {
              reasoningEffort = "xhigh";
            };
            max = {
              reasoningEffort = "max";
            };
          };
        };
        "gpt-5.5" = {
          name = "GPT 5.5";
          modalities = {
            input = [
              "text"
              "image"
              "pdf"
            ];
            output = [
              "text"
            ];
          };
          attachment = true;
          reasoning = true;
          temperature = false;
          tool_call = true;
          limit = {
            context = 1050000;
            input = 922000;
            output = 128000;
          };
          variants = {
            none = {
              reasoningEffort = "none";
            };
            low = {
              reasoningEffort = "low";
            };
            medium = {
              reasoningEffort = "medium";
            };
            high = {
              reasoningEffort = "high";
            };
            xhigh = {
              reasoningEffort = "xhigh";
            };
          };
        };
        "gpt-5.4" = {
          name = "GPT 5.4";
          modalities = {
            input = [
              "text"
              "image"
              "pdf"
            ];
            output = [
              "text"
            ];
          };
          attachment = true;
          reasoning = true;
          temperature = false;
          tool_call = true;
          limit = {
            context = 1050000;
            input = 922000;
            output = 128000;
          };
          variants = {
            none = {
              reasoningEffort = "none";
            };
            low = {
              reasoningEffort = "low";
            };
            medium = {
              reasoningEffort = "medium";
            };
            high = {
              reasoningEffort = "high";
            };
            xhigh = {
              reasoningEffort = "xhigh";
            };
          };
        };
        "gpt-5.4-mini" = {
          name = "GPT 5.4 Mini";
          modalities = {
            input = [
              "text"
              "image"
            ];
            output = [
              "text"
            ];
          };
          attachment = true;
          reasoning = true;
          temperature = false;
          tool_call = true;
          limit = {
            context = 400000;
            input = 272000;
            output = 128000;
          };
          variants = {
            none = {
              reasoningEffort = "none";
            };
            low = {
              reasoningEffort = "low";
            };
            medium = {
              reasoningEffort = "medium";
            };
            high = {
              reasoningEffort = "high";
            };
            xhigh = {
              reasoningEffort = "xhigh";
            };
          };
        };
        "claude-fable-5" = {
          name = "Claude Fable 5";
          modalities = {
            input = [
              "text"
              "image"
              "pdf"
            ];
            output = [
              "text"
            ];
          };
          attachment = true;
          reasoning = true;
          temperature = false;
          tool_call = true;
          limit = {
            context = 1000000;
            output = 128000;
          };
          variants = {
            low = {
              reasoningEffort = "low";
            };
            medium = {
              reasoningEffort = "medium";
            };
            high = {
              reasoningEffort = "high";
            };
            xhigh = {
              reasoningEffort = "xhigh";
            };
            max = {
              reasoningEffort = "max";
            };
          };
        };
        "claude-opus-5" = {
          name = "Claude Opus 5";
          modalities = {
            input = [
              "text"
              "image"
              "pdf"
            ];
            output = [
              "text"
            ];
          };
          attachment = true;
          reasoning = true;
          temperature = false;
          tool_call = true;
          limit = {
            context = 1000000;
            output = 128000;
          };
          variants = {
            low = {
              reasoningEffort = "low";
            };
            medium = {
              reasoningEffort = "medium";
            };
            high = {
              reasoningEffort = "high";
            };
            xhigh = {
              reasoningEffort = "xhigh";
            };
            max = {
              reasoningEffort = "max";
            };
          };
        };
        "claude-opus-4-8" = {
          name = "Claude Opus 4.8";
          modalities = {
            input = [
              "text"
              "image"
              "pdf"
            ];
            output = [
              "text"
            ];
          };
          attachment = true;
          reasoning = true;
          temperature = false;
          tool_call = true;
          limit = {
            context = 1000000;
            output = 128000;
          };
          variants = {
            low = {
              reasoningEffort = "low";
            };
            medium = {
              reasoningEffort = "medium";
            };
            high = {
              reasoningEffort = "high";
            };
            xhigh = {
              reasoningEffort = "xhigh";
            };
            max = {
              reasoningEffort = "max";
            };
          };
        };
        "claude-opus-4-7" = {
          name = "Claude Opus 4.7";
          modalities = {
            input = [
              "text"
              "image"
              "pdf"
            ];
            output = [
              "text"
            ];
          };
          attachment = true;
          reasoning = true;
          temperature = false;
          tool_call = true;
          limit = {
            context = 1000000;
            output = 128000;
          };
          variants = {
            low = {
              reasoningEffort = "low";
            };
            medium = {
              reasoningEffort = "medium";
            };
            high = {
              reasoningEffort = "high";
            };
            xhigh = {
              reasoningEffort = "xhigh";
            };
            max = {
              reasoningEffort = "max";
            };
          };
        };
        "claude-opus-4-6" = {
          name = "Claude Opus 4.6";
          modalities = {
            input = [
              "text"
              "image"
              "pdf"
            ];
            output = [
              "text"
            ];
          };
          attachment = true;
          reasoning = true;
          temperature = false;
          tool_call = true;
          limit = {
            context = 200000;
            output = 128000;
          };
          variants = {
            low = {
              reasoningEffort = "low";
            };
            medium = {
              reasoningEffort = "medium";
            };
            high = {
              reasoningEffort = "high";
            };
            max = {
              reasoningEffort = "max";
            };
          };
        };
        "claude-sonnet-5" = {
          name = "Claude Sonnet 5";
          modalities = {
            input = [
              "text"
              "image"
              "pdf"
            ];
            output = [
              "text"
            ];
          };
          attachment = true;
          reasoning = true;
          temperature = false;
          tool_call = true;
          limit = {
            context = 1000000;
            output = 128000;
          };
          variants = {
            low = {
              reasoningEffort = "low";
            };
            medium = {
              reasoningEffort = "medium";
            };
            high = {
              reasoningEffort = "high";
            };
            xhigh = {
              reasoningEffort = "xhigh";
            };
            max = {
              reasoningEffort = "max";
            };
          };
        };
        "claude-sonnet-4-6" = {
          name = "Claude Sonnet 4.6";
          modalities = {
            input = [
              "text"
              "image"
              "pdf"
            ];
            output = [
              "text"
            ];
          };
          attachment = true;
          reasoning = true;
          temperature = false;
          tool_call = true;
          limit = {
            context = 200000;
            output = 64000;
          };
          variants = {
            low = {
              reasoningEffort = "low";
            };
            medium = {
              reasoningEffort = "medium";
            };
            high = {
              reasoningEffort = "high";
            };
            max = {
              reasoningEffort = "max";
            };
          };
        };
        "claude-haiku-4-5" = {
          name = "Claude Haiku 4.5";
          modalities = {
            input = [
              "text"
              "image"
              "pdf"
            ];
            output = [
              "text"
            ];
          };
          attachment = true;
          reasoning = true;
          temperature = false;
          tool_call = true;
          limit = {
            context = 200000;
            output = 64000;
          };
        };
        "glm-5.2" = {
          name = "GLM 5.2";
          modalities = {
            input = [
              "text"
            ];
            output = [
              "text"
            ];
          };
          attachment = false;
          reasoning = true;
          temperature = true;
          tool_call = true;
          limit = {
            context = 262144;
            output = 32768;
          };
          variants = {
            high = {
              reasoningEffort = "high";
            };
            max = {
              reasoningEffort = "max";
            };
          };
        };
        "grok-4.5" = {
          name = "Grok 4.5";
          modalities = {
            input = [
              "text"
            ];
            output = [
              "text"
            ];
          };
          attachment = false;
          reasoning = true;
          temperature = false;
          tool_call = true;
          limit = {
            input = 512000;
            output = 128000;
            context = 512000;
          };
          variants = {
            low = {
              reasoningEffort = "low";
            };
            medium = {
              reasoningEffort = "medium";
            };
            high = {
              reasoningEffort = "high";
            };
          };
        };
        "composer-2.5-fast" = {
          name = "Composer 2.5 Fast";
          modalities = {
            input = [
              "text"
            ];
            output = [
              "text"
            ];
          };
          attachment = false;
          reasoning = false;
          temperature = true;
          tool_call = true;
          limit = {
            input = 200000;
            output = 64000;
            context = 200000;
          };
        };
        "qwen3.7-max" = {
          name = "Qwen3.7 Max";
          modalities = {
            input = [
              "text"
            ];
            output = [
              "text"
            ];
          };
          attachment = false;
          reasoning = true;
          temperature = true;
          tool_call = true;
          limit = {
            context = 1000000;
            output = 65536;
          };
        };
        "qwen3.7-plus" = {
          name = "Qwen3.7 Plus";
          modalities = {
            input = [
              "text"
              "image"
              "video"
            ];
            output = [
              "text"
            ];
          };
          attachment = true;
          reasoning = true;
          temperature = true;
          tool_call = true;
          limit = {
            context = 1000000;
            output = 65536;
          };
        };
        "kimi-k3" = {
          name = "Kimi K3";
          modalities = {
            input = [
              "text"
              "image"
              "video"
            ];
            output = [
              "text"
            ];
          };
          attachment = true;
          reasoning = true;
          temperature = false;
          tool_call = true;
          limit = {
            context = 1000000;
            output = 131072;
          };
          variants = {
            low = {
              reasoningEffort = "low";
            };
            high = {
              reasoningEffort = "high";
            };
            max = {
              reasoningEffort = "max";
            };
          };
        };
        "kimi-k2.7-code" = {
          name = "Kimi K2.7 Code";
          modalities = {
            input = [
              "text"
              "image"
              "video"
            ];
            output = [
              "text"
            ];
          };
          attachment = true;
          reasoning = true;
          temperature = false;
          tool_call = true;
          limit = {
            context = 262144;
            output = 262144;
          };
        };
        "deepseek-v4-pro" = {
          name = "DeepSeek V4 Pro";
          modalities = {
            input = [
              "text"
            ];
            output = [
              "text"
            ];
          };
          attachment = false;
          reasoning = true;
          temperature = true;
          tool_call = true;
          limit = {
            context = 1000000;
            output = 384000;
          };
          variants = {
            low = {
              reasoningEffort = "low";
            };
            medium = {
              reasoningEffort = "medium";
            };
            high = {
              reasoningEffort = "high";
            };
            max = {
              reasoningEffort = "max";
            };
          };
        };
        "deepseek-v4-flash" = {
          name = "DeepSeek V4 Flash";
          modalities = {
            input = [
              "text"
            ];
            output = [
              "text"
            ];
          };
          attachment = false;
          reasoning = true;
          temperature = true;
          tool_call = true;
          limit = {
            context = 1000000;
            output = 384000;
          };
          variants = {
            low = {
              reasoningEffort = "low";
            };
            medium = {
              reasoningEffort = "medium";
            };
            high = {
              reasoningEffort = "high";
            };
            max = {
              reasoningEffort = "max";
            };
          };
        };
        "minimax-m3" = {
          name = "MiniMax M3";
          modalities = {
            input = [
              "text"
              "image"
              "video"
            ];
            output = [
              "text"
            ];
          };
          attachment = false;
          reasoning = true;
          temperature = true;
          tool_call = true;
          limit = {
            context = 1000000;
            output = 131072;
          };
          variants = {
            none = {
              reasoningEffort = "none";
            };
            thinking = {
              reasoningEffort = "thinking";
            };
          };
        };
        "mimo-v2.5-pro" = {
          name = "MiMo V2.5 Pro";
          modalities = {
            input = [
              "text"
            ];
            output = [
              "text"
            ];
          };
          attachment = true;
          reasoning = true;
          temperature = true;
          tool_call = true;
          limit = {
            context = 1048576;
            output = 128000;
          };
          variants = {
            low = {
              reasoningEffort = "low";
            };
            medium = {
              reasoningEffort = "medium";
            };
            high = {
              reasoningEffort = "high";
            };
          };
        };
        "mimo-v2.5" = {
          name = "MiMo V2.5";
          modalities = {
            input = [
              "text"
              "image"
              "audio"
              "video"
            ];
            output = [
              "text"
            ];
          };
          attachment = true;
          reasoning = true;
          temperature = true;
          tool_call = true;
          limit = {
            context = 1000000;
            output = 128000;
          };
          variants = {
            low = {
              reasoningEffort = "low";
            };
            medium = {
              reasoningEffort = "medium";
            };
            high = {
              reasoningEffort = "high";
            };
          };
        };
        "nemotron-3-ultra" = {
          name = "Nemotron 3 Ultra";
          modalities = {
            input = [
              "text"
            ];
            output = [
              "text"
            ];
          };
          attachment = false;
          reasoning = true;
          temperature = true;
          tool_call = true;
          limit = {
            context = 1000000;
            output = 128000;
          };
          variants = {
            low = {
              reasoningEffort = "low";
            };
            medium = {
              reasoningEffort = "medium";
            };
            high = {
              reasoningEffort = "high";
            };
          };
        };
        "north-mini-code" = {
          name = "North Mini Code";
          modalities = {
            input = [
              "text"
            ];
            output = [
              "text"
            ];
          };
          attachment = false;
          reasoning = true;
          temperature = true;
          tool_call = true;
          limit = {
            context = 256000;
            output = 64000;
          };
          variants = {
            none = {
              reasoningEffort = "none";
            };
            high = {
              reasoningEffort = "high";
            };
          };
        };
      };
    };
  };
}
