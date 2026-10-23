{
  lib,
  config,
  namespace,
  ...
}: let
  inherit (lib.${namespace}) source;

  cfg = config.${namespace}.ai-assistance.opencode;

  # T1 inner harness provisioner (ADR 0007 D1): namespace-generated name, kept
  # identical to the one used in `logseq-profiles.nix` / `mcp.nix` (falls back
  # to the green default when the home-side config does not carry `common`).
  spiceNamespace = (config.lib.${namespace}.common or {}).spiceNamespace or "darkGreen";
  innerProvisionerAgent = "${spiceNamespace}-inner-conv-plat-prov";
in
  {
    imports = [
      ./opencode-docker-fix.nix
      ./mcp.nix
      ./mcp-compose.nix
      ./logseq-profiles.nix
      ./providers/opencode-cheapvibecode.provider.nix
      ./tools/pizza.nix
      ./tools/taskwarrior.nix
      ./tools/zotero.nix
      ./skills/logseq-db-queries.nix
      ./skills/logseq-authoring.nix
      ./skills/logseq-authoring-suite.nix
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
        # Always-on guidance, unlike on-demand skills: loaded for every agent
        # and every session. Kept short; the full conventions live in the
        # logseq-authoring skill. See instructions/logseq-references.md.
        instructions = [
          (toString ./instructions/logseq-references.md)
        ];

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
        orchestrator = ./agents/orchestrator.md;
        strategist = ./agents/strategist.md;
        tactician = ./agents/tactician.md;
        architect = ./agents/architect.md;
        researcher = ./agents/researcher.md;
        analyst = ./agents/analyst.md;
        nix-analyst = ./agents/nix-analyst.md;
        reporter = ./agents/reporter.md;
        plan = ./agents/plan.md;
        build = ./agents/build.md;
        nix-plan = ./agents/nix-plan.md;
        nix-build = ./agents/nix-build.md;
        verifier = ./agents/verifier.md;
        kbn = ./agents/kbn.md;
        # T1 inner harness provisioner (primary, Logseq-producing) — the name is
        # namespace-generated (`<spiceNamespace>-inner-conv-plat-prov`).
        "${innerProvisionerAgent}" = ./agents/darkGreen-inner-conv-plat-prov.md;
        # T2 harness provisioner (subagent, no Logseq) — the single door for
        # harness edits; namespace-agnostic.
        harness-conv-plat-prov = ./agents/harness-conv-plat-prov.md;
        # Delivery summary personas are wired in mcp.nix `settings.agent` as
        # hidden JSON subagents (the <parent>-kbn counterpart), so `agents`
        # only needs the authoring personas above.
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
          "logseq-authoring"
          "logseq-authoring-suite"
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
