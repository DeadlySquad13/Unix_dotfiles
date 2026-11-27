{
  lib,
  ...
}:
let
  inherit (builtins) listToAttrs map;
  inherit (lib) strings;

  # In most cases we jump directly into folder. This way common .envrc wouldn't
  # be hooked. This envrc allows us to source it from a central point in each
  # subdirectory.
  # But we use flake here instead of in common .envrc for two reasons:
  # 1. I don't need to source into flake shell when working in parent dir and their configs
  # (outside of worktree).
  # 2. We may need to separate them per worktree in the future
  envrc = /* bash */ ''
    # Flake must be inside git repo (and not ignored), otherwise it would need to clone
    # a whole repo to the nix store. Hence we move it to parent dir with
    # a subdir that has git initialized.
    use flake ../_configs/Nix/flake.nix

    source_env_if_exists ../.envrc

    # vi:ft=bash
  '';

  # Project root `.envrc` (one per project, not per worktree).
  projectEnvrc = /* bash */ ''
    dotenv ./.env.dev
    # TODO: Remove temporary workaround when it's properly fixed https://github.com/NixOS/nixpkgs/issues/376958
    unset DEVELOPER_DIR
    # Conflicts with AutoHub .env variable GITLAB_TOKEN. See glab
    # module. This token is personal either way, so unsetting in all work projects.
    unset GITLAB_TOKEN

    # vi:ft=bash
  '';

  projectEnvDev = /* bash */ ''
    # Disable auto-setting of `packageManager` when corepack is enabled.
    COREPACK_ENABLE_AUTO_PIN=0

    # vi:ft=bash
  '';

  # Local for repository, personal to our workflow gitignore file.
  # https://git-scm.com/docs/gitignore,
  # https://stackoverflow.com/questions/1753070/how-do-i-configure-git-to-ignore-some-files-locally
  gitExclude = /* gitignore */ ''
    # Usually not ignored, but our members don't use it, it's for our personal
    # solution of a corepack issue and flake configs.
    .envrc
    .direnv
  '';

  # TODO: Get from
  # rut-Programming_dotfiles/roles/repositories/vars/main.yml
  defaultWorktrees = [
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
  # Nix will create a new (empty) directory under specified path.
  # @attr worktrees - optional list of worktrees used in a project.
  # TODO: Get from
  # rut-Programming_dotfiles/roles/repositories/vars/main.yml
  defaultProjects =
    {
      rutubeProjectsRoot,
      relativePrefix ? "--professional/Rutube__",
    }:
    [
      {
        suiteName = "Woodpecker";
        logicalPath = "${relativePrefix}/Woodpecker";
        path = "${rutubeProjectsRoot}/Woodpecker";
      }
      {
        suiteName = "Premium";
        logicalPath = "${relativePrefix}/Premium";
        path = "${rutubeProjectsRoot}/Premium";
      }
      {
        suiteName = "Raichu";
        logicalPath = "${relativePrefix}/Raichu";
        path = "${rutubeProjectsRoot}/Raichu";
      }
      {
        suiteName = "ReleaseBuilder";
        logicalPath = "${relativePrefix}/ReleaseBuilder";
        path = "${rutubeProjectsRoot}/ReleaseBuilder";
      }
      {
        suiteName = "AutoHub";
        logicalPath = "${relativePrefix}/AutoHub";
        path = "${rutubeProjectsRoot}/AutoHub";
      }
    ];

  /*
    Return the project path relative to the synced projects root.

    Generated paths are addressed relative to the synced root so the same model
    can drive the Syncthing ignore list, the salt generation root, and the
    project-local links without embedding a host prefix.
  */
  projectLogicalPath =
    { projectsRoot, projectPath }:
    let
      root = strings.removeSuffix "/" (toString projectsRoot);
      path = strings.removeSuffix "/" (toString projectPath);
    in
    if strings.hasPrefix "${root}/" path then
      strings.removePrefix "${root}/" path
    else
      throw "project-configs: project path '${path}' is not under projectsRoot '${root}'";

  /*
    Pure form of the original `map-project-worktrees-to-smug-configs`.

    `pathIsDirectory` is injected so this function never touches the filesystem:
    the host glue decides whether the suite-specific Smug config directory exists
    and passes a predicate. The default Smug config directory is used otherwise.

    Returns `_configs/<worktree>.yml` -> `{ kind = "file"; source = "<abs>"; }`
    keyed relative to the project directory.
  */
  mapProjectWorktreesToSmugConfigs =
    {
      smugRoot,
      worktrees ? defaultWorktrees,
      pathIsDirectory,
    }:
    project:
    let
      projectWorktrees = project.worktrees or worktrees;
      projectSpecific = "${smugRoot}/${project.suiteName}";
      fallback = "${smugRoot}/-gitWorktrees";
      selected = if pathIsDirectory projectSpecific then projectSpecific else fallback;
    in
    listToAttrs (
      map (worktree: {
        name = "_configs/${worktree}.yml";
        value = {
          kind = "file";
          source = "${selected}/${worktree}.yml";
        };
      }) projectWorktrees
    );

  /*
    Project-relative generated entries for a single project:

    - `_configs/Nix` (dir)
    - `_scripts` (dir)
    - `_configs/<worktree>.yml` (file, from the Smug config tree)

    Keys are relative to the project directory; `projectStructures` prefixes them
    with the logical project path.
  */
  createProjectConfigs =
    {
      projectsRoot,
      nixConfigsRoot,
      scriptsRoot,
      smugRoot,
      worktrees ? defaultWorktrees,
      pathIsDirectory,
    }:
    project:
    let
      # Prefer an explicit logical path: it keeps the ignore list independent of
      # the host-specific projects root (and therefore of the Syncthing folder
      # option). Fall back to deriving it from the absolute project path.
      logical =
        project.logicalPath or (projectLogicalPath {
          inherit projectsRoot;
          projectPath = project.path;
        });
    in
    {
      "${logical}/_configs/Nix" = {
        kind = "dir";
        source = "${nixConfigsRoot}/${project.suiteName}";
      };
      "${logical}/_scripts" = {
        kind = "dir";
        source = scriptsRoot;
      };
    }
    //
      lib.mapAttrs'
        (name: value: {
          name = "${logical}/${name}";
          inherit value;
        })
        (
          mapProjectWorktreesToSmugConfigs {
            inherit smugRoot worktrees pathIsDirectory;
          } project
        );

  /*
    Pure generator model.

    Returns a logical path (relative to `projectsRoot`) -> entry attrset:

      `{ kind = "file" | "dir"; source = "<absolute host path>"; }`
      `{ kind = "text"; text = "<literal content>"; }`

    No `home.file`, no `config`, no `out-of-store` decisions: consumers decide how
    to materialise the entries (Darwin store links, salt activation writer).
  */
  projectStructures =
    {
      projectsRoot,
      rutubeProjectsRoot,
      smugRoot ? "${rutubeProjectsRoot}/_configs/Smug__",
      nixConfigsRoot ? "${rutubeProjectsRoot}/_configs/Nix__",
      scriptsRoot ? "${rutubeProjectsRoot}/_scripts",
      projects ? defaultProjects { inherit rutubeProjectsRoot; },
      worktrees ? defaultWorktrees,
      pathIsDirectory,
    }:
    let
      perProject =
        project:
        let
          logical =
            project.logicalPath or (projectLogicalPath {
              inherit projectsRoot;
              projectPath = project.path;
            });
          projectWorktrees = project.worktrees or worktrees;
          textEntry = name: text: {
            name = "${logical}/${name}";
            value = {
              kind = "text";
              inherit text;
            };
          };
        in
        createProjectConfigs {
          inherit
            projectsRoot
            nixConfigsRoot
            scriptsRoot
            smugRoot
            worktrees
            pathIsDirectory
            ;
        } project
        // listToAttrs [
          (textEntry ".envrc" projectEnvrc)
          (textEntry ".env.dev" projectEnvDev)
        ]
        // listToAttrs (map (worktree: textEntry "${worktree}/.envrc" envrc) projectWorktrees)
        // listToAttrs [
          (textEntry "${project.suiteName}.git/.git/info/exclude" gitExclude)
        ];
    in
    lib.lists.foldl' (acc: project: acc // perProject project) { } projects;

  /*
    Syncthing `rut-Projects` ignore patterns derived from the same model.

    One root-anchored pattern per generated logical path. Tier 2 discovery
    (`scripts/project-configs-salt.py --discover`) is a drift check on top of this
    list; it must never be the primary boundary.
  */
  ignorePatterns = structures: map (logical: "/${logical}") (builtins.attrNames structures);

  /*
    Path of a generated logical entry inside the generation root.

    The generation root mirrors the home-relative project tree
    (`<generationRoot>/Projects/<logical>`), which is why the `Projects` component
    is part of the manifest and link targets.
  */
  generationRelativePath =
    {
      projectsRootName,
      logical,
    }:
    "${projectsRootName}/${logical}";
in
{
  inherit
    envrc
    projectEnvrc
    projectEnvDev
    gitExclude
    defaultWorktrees
    defaultProjects
    projectLogicalPath
    mapProjectWorktreesToSmugConfigs
    createProjectConfigs
    projectStructures
    ignorePatterns
    generationRelativePath
    ;
}
