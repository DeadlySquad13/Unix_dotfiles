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
  rutube-projects-root = "${projects-root}/--professional/Rutube__";
  # TODO: Get from
  # rut-Programming_dotfiles/roles/repositories/vars/main.yml
  rutube-projects-worktrees = [
    "CurrentTask"
    "CurrentTask1"
    "Epic"
    "Main"
    "Release"
    "Review"
  ];

  # INFO: 
  # @attr path - location of the project. If it is located in different
  # directory, symlink should be added before running this flake. Otherwise
  # Nix will create a new directory under specified path.
  # @attr worktrees - list of worktrees used in a project.
  # TODO: Get from
  # rut-Programming_dotfiles/roles/repositories/vars/main.yml
  projects = [
    {
      suite-name = "Woodpecker";
      path = "${rutube-projects-root}/Woodpecker";
    }
    {
      suite-name = "Premium";
      path = "${rutube-projects-root}/Premium";
    }
    {
      suite-name = "Raichu";
      path = "${rutube-projects-root}/Raichu";
    }
    {
      suite-name = "ReleaseBuilder";
      path = "${rutube-projects-root}/ReleaseBuilder";
    }
  ];

  map-project-worktrees-to-smug-configs = project:
    lib.lists.foldl (
      acc: worktree: let
        # Choosing different configs.
        smug-worktree-configs-root = "${rutube-projects-root}/_configs/Smug__";
        project-specific-smug-worktree-configs = "${smug-worktree-configs-root}/${project.suite-name}";
        default-smug-worktree-configs = "${smug-worktree-configs-root}/-gitWorktrees";

        smug-worktree-configs =
          if lib.filesystem.pathIsDirectory project-specific-smug-worktree-configs
          then project-specific-smug-worktree-configs
          else default-smug-worktree-configs;
      in
        acc
        // {
          "_configs/${worktree}.yml" = "${smug-worktree-configs}/${worktree}.yml";
        }
    ) {} (project.worktrees or rutube-projects-worktrees);

  create-project-configs = project:
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
      lib.attrsets.concatMapAttrs (name: value: {"${project.path}/${name}" = value;}) (
        # - Nix
        {
          "_configs/Nix" = "${rutube-projects-root}/_configs/Nix__/${project.suite-name}";
        }
        # - Smug Git Worktrees.
        // (map-project-worktrees-to-smug-configs project)
      )
    );

  # Project local disable of automatic corepack pinning of package manager version.
  project-structures =
    lib.lists.foldl (
      acc: project:
        acc
        // (create-project-configs project)
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
          # TODO: Separate list based on project. Use `project.worktrees` like
          # in smug config
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
    # in nix repl to debug.
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
          "shared-projects" = paths.shared-projects;
        }
      )
      // project-structures;
  }
