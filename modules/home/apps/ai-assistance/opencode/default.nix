{
  lib,
  config,
  namespace,
  ...
}: let
  inherit (lib.${namespace}) source;

  cfg = config.${namespace}.ai-assistance.opencode;
in
  {
    imports = [
      ./opencode-docker-fix.nix
      ./mcp.nix
      ./providers/opencode-cheapvibecode.provider.nix
      ./tools/pizza.nix
      ./tools/taskwarrior.nix
      ./tools/zotero.nix
      ./skills/logseq-db-queries.nix
      ./skills/file-organizer.nix
      ./skills/mcp-builder.nix
      ./skills/skill-creator.nix
      ./skills/add-opencode-skill-to-unix-dotfiles.nix
      ./skills/changelog-generator.nix
    ];
  }
  // lib.${namespace}.mkIfEnabled
  {
    inherit config;
    category = "ai-assistance";
    name = "opencode";
  }
  {
    # Override only if more relevant file is defined at home-manager level.
    # Otherwise don't change config defined on a system level.
    home.file.".local/share/opencode/auth.json" =
      lib.mkIf (builtins.hasAttr "opencode-auth.json" config.sops.templates)
      (
        # Sops template is not guaranteed to exist in nix store during build so
        # we're symlinking to it's predetermined location: it will be available
        # once program is run.
        source {
          inherit config;
          get-path = _p: config.sops.templates."opencode-auth.json".path;
          out-of-store = true;
        }
      );

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
          # openai = {
          #   options = {
          #     baseURL = "https://alt.codexapi.work/v1";
          #   };
          # };
        };
      };

      skills = lib.mkDefault {};

      inherit (cfg) enabledSkills customTools;

      agents = {
        prompt-designer = ./agents/prompt-designer.md;
        coding = ./agents/coding.md;
        kbn =
          /*
          md
          */
          ''
            ---
            description: Writes and maintains project documentation
            mode: primary
            permission:
              bash: deny
            ---

            You are a technical writer. Create clear, comprehensive documentation.

            Focus on:

            - Clear explanations
            - Proper structure
            - Code examples
            - User-friendly language
          '';
        docs-writer =
          /*
          md
          */
          ''
            ---
            description: Writes and maintains project documentation
            mode: subagent
            permission:
              bash: deny
            ---

            You are a technical writer. Create clear, comprehensive documentation.

            Focus on:

            - Clear explanations
            - Proper structure
            - Code examples
            - User-friendly language
          '';
        security-auditor = ''
          ---
          description: Performs security audits and identifies vulnerabilities
          mode: subagent
          permission:
            edit: deny
          ---

          You are a security expert. Focus on identifying potential security issues.

          Look for:

          - Input validation vulnerabilities
          - Authentication and authorization flaws
          - Data exposure risks
          - Dependency vulnerabilities
          - Configuration security issues
        '';
      };
    };
  }
  // {
    options.programs.opencode = {
      aiAssistanceDir = lib.mkOption {
        type = lib.types.path;
        default = let
          projectsPath =
            if config.lib ? ${namespace} && config.lib.${namespace}.paths ? projects
            then
              lib.${namespace}.get-path {
                inherit config;
                as-string = true;
                cb = p: p.projects;
              }
            else null;
        in
          if projectsPath != null
          then "${projectsPath}/--personal/AiAssistance__"
          else "${config.home.homeDirectory}/Projects/--personal/AiAssistance__";
        defaultText = lib.literalExpression ''
          if config.lib.''${namespace}.paths ? projects
          then config.lib.''${namespace}.paths.projects + "/--personal/AiAssistance__"
          else config.home.homeDirectory + "/Projects/--personal/AiAssistance__"
        '';
        description = "Path to the AiAssistance repository root directory";
      };

      skillsDir = lib.mkOption {
        type = lib.types.path;
        default = "${config.programs.opencode.aiAssistanceDir}/_skills";
        defaultText = lib.literalExpression ''"''${config.programs.opencode.aiAssistanceDir}/_skills"'';
        description = "Directory containing opencode skills";
      };
    };

    options.${namespace}.ai-assistance.opencode = {
      enabledSkills =
        lib.genAttrs
        [
          "logseq-db-queries"
          "file-organizer"
          "mcp-builder"
          "skill-creator"
          "add-opencode-skill-to-unix-dotfiles"
          "changelog-generator"
        ]
        (
          name:
            lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable ${name} opencode skill";
            }
        );

      customTools =
        lib.genAttrs
        [
          "pizza"
          "taskwarrior"
          "zotero"
        ]
        (
          name:
            lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable ${name} opencode tool";
            }
        );
    };
  }
