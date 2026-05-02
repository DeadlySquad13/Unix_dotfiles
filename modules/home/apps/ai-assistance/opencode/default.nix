{lib, ...}: {
  imports = [
    ./opencode-docker-fix.nix
    ./tools/pizza.nix
    ./tools/taskwarrior.nix
    ./tools/zotero.nix
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

    skills = {
      logseq-db-queries = /shared/archive-resources-/Resources/KnowledgeBase__Data/-skills/logseq-db-queries;
      file-organizer = /home/ds13/Projects/--personal/AiAssistance__/_skills/file-organizer;
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
