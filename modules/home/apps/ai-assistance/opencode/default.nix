{lib, ...}: {
  imports = [
    ./opencode-docker-fix.nix
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

    skills = lib.mkDefault {};

    enabledSkills = {
      logseq-db-queries = true;
      file-organizer = true;
      mcp-builder = true;
      skill-creator = true;
      add-opencode-skill-to-unix-dotfiles = true;
      changelog-generator = true;
    };

    customTools = {
      pizza = true;
      taskwarrior = true;
      zotero = true;
    };

    agents = {
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
