{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib.${namespace}) source;
  inherit (config.lib.${namespace}) paths;

  # In most cases we jump directly into folder. This way common .envrc wouldn't
  # be hooked. This envrc allows us to source it from a central point in each
  # subdirectory.
  # But we use flake here instead of in common .envrc for two reasons:
  # 1. I don't need to source into flake shell when working in parent dir and their configs
  # (outside of worktree).
  # 2. We may need to separate them per worktree in the future
  envrc =
    # bash
    ''
      # Flake must be inside git repo (and not ignored), otherwise it would need to clone
      # a whole repo to the nix store. Hence we move it to parent dir with
      # a subdir that has git initialized.
      use flake ../_configs/Nix/flake.nix

      source_env_if_exists ../.envrc

      # vi:ft=bash
    '';

  projects-root = "${config.home.homeDirectory}/Projects";
  # TODO: Get from
  # rut-Programming_dotfiles/roles/repositories/vars/main.yml
  projects = [
    {
      suite-name = "Woodpecker";
      path = "${projects-root}/--professional/Rutube__/Woodpecker";
    }
    {
      suite-name = "Premium";
      path = "${projects-root}/--professional/Rutube__/Premium";
    }
  ];

  # Project local disable of automatic corepack pinning of package manager version.
  project-structures =
    lib.lists.foldl (
      acc: project:
        acc
        // lib.attrsets.concatMapAttrs (name: value: {"${project.path}/${name}" = value;}) (
          {
            ".envrc".text =
              # bash
              ''
                dotenv ./.env.dev
                # TODO: Remove temporary workaround when it's properly fixed https://github.com/NixOS/nixpkgs/issues/376958
                unset DEVELOPER_DIR

                # vi:ft=bash
              '';
            ".env.dev".text =
              # bash
              ''
                # Disable auto-setting of `packageManager` when corepack is enabled.
                COREPACK_ENABLE_AUTO_PIN=0

                # vi:ft=bash
              '';
          }
          # Iterating over all worktrees.
          # TODO: Ideally should be based on current worktree structure, not just
          # hardcoded paths.
          # TODO: Separate list based on project.
          // lib.attrsets.concatMapAttrs (projectName: value: {"${projectName}/.envrc".text = envrc;}) {
            "CurrentTask" = "";
            "CurrentTask1" = "";
            "Epic" = "";
            "Main" = ""; # Actually symlink to <ProjectSuiteName>.git. <ProjectSuiteName>.git is also symlinked to Master.
            "Release" = "";
            "Review" = "";
          }
          // {
            # Local for repository, personal to our workflow gitignore file.
            # https://git-scm.com/docs/gitignore,
            # https://stackoverflow.com/questions/1753070/how-do-i-configure-git-to-ignore-some-files-locally
            "${project.suite-name}.git/.git/info/exclude".text =
              # gitignore
              ''
                # Usually not ignored, but our members don't use it, it's for our personal
                # solution of a corepack issue and flake configs.
                .envrc
                .direnv
              '';
          }
        )
    ) {}
    projects;
in
  lib.${namespace}.mkIfEnabled
  {
    inherit config;
    category = "bookmarks";
    name = "darwin";
    extraPredicate = lib.${namespace}.mkIfDarwin;
  }
  {
    # See `darwinConfigurations.creamsoda.config.home-manager.users.apakalo.home.file.`
    # in nix-repl to debug.
    home.file =
      builtins.mapAttrs
      (
        name: value:
          source {
            inherit config;
            get-path = _p: value;
            out-of-store = true;
          }
      )
      (
        lib.attrsets.concatMapAttrs (name: value: {".bookmarks/${name}" = value;}) {
          "ChronoIndex" = "~/ChronoIndex";
          "KnowledgeBase__Data" = "~/KnowledgeBase__Data";
          "kbd" = "~/KnowledgeBase__Data";
          "kbn" = "~/KnowledgeBase__Data/Notes";
          "shared-configs" = paths.shared-configs;
        }
      )
      // project-structures;
  }
