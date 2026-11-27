{
  config,
  lib,
  namespace,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types;
  # Snowfall passes its own merged `lib`, which does not carry Home Manager's
  # `hm` fixpoint; `config.lib` is Home Manager's extended lib, so the DAG
  # helper is reached through it (same pattern as termfilechooser).
  inherit (config.lib) dag;
  inherit
    (lib.${namespace})
    defaultProjects
    defaultWorktrees
    ignorePatterns
    projectLogicalPath
    projectStructures
    ;

  cfg = config.${namespace}.bookmarks.projects;

  # Resolve `~/...` consistently: syncthing folder paths and explicit options
  # may be written either way.
  expandHome = value: let
    path = toString value;
  in
    if lib.hasPrefix "~/" path
    then "${config.home.homeDirectory}/${lib.removePrefix "~/" path}"
    else path;

  # Phase 0 makes the real synced path authoritative; until then the Syncthing
  # folder option is the source of truth, with `~/Projects` as the last resort.
  syncthingFolderPath =
    lib.attrByPath
    ["services" "syncthing" "settings" "folders" cfg.syncthingFolderName "path"]
    null
    config;

  resolvedProjectsRoot =
    if cfg.projectsRoot != null
    then expandHome cfg.projectsRoot
    else if syncthingFolderPath != null
    then expandHome syncthingFolderPath
    else "${config.home.homeDirectory}/Projects";

  rutubeProjectsRoot = expandHome cfg.rutubeProjectsRoot;
  smugRoot = expandHome cfg.smugRoot;
  nixConfigsRoot = expandHome cfg.nixConfigsRoot;
  scriptsRoot = expandHome cfg.scriptsRoot;
  generationRoot = expandHome cfg.generationRoot;
  manifestPath = expandHome cfg.manifestPath;

  projectsRootName = baseNameOf (lib.removeSuffix "/" resolvedProjectsRoot);

  structures = projectStructures {
    projectsRoot = resolvedProjectsRoot;
    inherit rutubeProjectsRoot smugRoot nixConfigsRoot scriptsRoot;
    inherit (cfg) projects worktrees;
    # The pure model never touches the filesystem. The suite-specific Smug
    # config directory is a host fact, so the predicate is supplied here.
    pathIsDirectory = lib.filesystem.pathIsDirectory;
  };

  projectIgnorePatterns = ignorePatterns structures;

  # `home.file` can only materialise paths under `$HOME` (Home Manager rejects
  # absolute targets outside it). The salt host uses `writeMode = "activation"`.
  mkHomeFileEntry = logical: entry:
    if entry.kind == "text"
    then {text = entry.text;}
    else {
      source = config.lib.file.mkOutOfStoreSymlink entry.source;
      recursive = true;
    };

  payloadEntries =
    lib.mapAttrsToList (
      logical: entry:
        {inherit logical;}
        // {inherit (entry) kind;}
        // (
          if entry.kind == "text"
          then {inherit (entry) text;}
          else {inherit (entry) source;}
        )
    )
    structures;

  # Consumed by the activation writer and by the `project-configs-salt*` Make
  # targets. Paths in the payload are host-local by construction.
  payload = {
    schema_version = 1;
    syncthing_root = resolvedProjectsRoot;
    projects_root = resolvedProjectsRoot;
    generation_root = generationRoot;
    manifest_path = manifestPath;
    ignore_patterns = projectIgnorePatterns;
    entries = payloadEntries;
  };

  generatorPayloadFile = pkgs.writeText "agent-project-configs.json" (builtins.toJSON payload);

  generatorArgs =
    ["--input" (toString generatorPayloadFile)]
    ++ lib.optionals cfg.writeLinks ["--write-links"]
    ++ lib.optionals (!cfg.prune) ["--no-prune"]
    ++ lib.optionals (cfg.ignoreBoundaryFile != null) [
      "--effective-ignore-file"
      (toString cfg.ignoreBoundaryFile)
    ]
    ++ lib.optionals (cfg.ignoreBoundaryCommand != null) [
      "--effective-ignore-cmd"
      cfg.ignoreBoundaryCommand
    ];
in
  lib.${namespace}.mkIfEnabled
  {
    inherit config;
    category = "bookmarks";
    name = "projects";
    # RFC 4.2: explicit enable. The category gate alone would enable this module
    # on every host with `bookmarks.enable = true` (e.g. @cake, @MelisStoke),
    # where the project tree does not exist. Only @creamsoda and @salt opt in.
    extraPredicate = {module-cfg, ...}: module-cfg ? enable && module-cfg.enable;
  }
  {
    assertions = [
      {
        assertion = lib.hasPrefix "/" resolvedProjectsRoot;
        message = "${namespace}.bookmarks.projects.projectsRoot must be an absolute path: ${resolvedProjectsRoot}";
      }
      {
        assertion = lib.hasPrefix "/" generationRoot;
        message = "${namespace}.bookmarks.projects.generationRoot must be an absolute path: ${generationRoot}";
      }
      {
        assertion = lib.hasPrefix "/" manifestPath;
        message = "${namespace}.bookmarks.projects.manifestPath must be an absolute path: ${manifestPath}";
      }
      {
        assertion =
          cfg.writeMode != "home.file"
          || lib.hasPrefix (config.home.homeDirectory + "/") resolvedProjectsRoot;
        message = "${namespace}.bookmarks.projects: writeMode = \"home.file\" can only target paths under $HOME (${config.home.homeDirectory}); use \"activation\" for ${resolvedProjectsRoot}";
      }
    ];

    # Tier 1 Syncthing boundary is exposed as the `ignorePatterns` option default
    # below; the Syncthing home modules append it.
    # Keep both write branches behind `mkIf` (not `optionalAttrs`): the module
    # body is constructed while `config` is still being evaluated, so an eager
    # `cfg.writeMode` check here would recurse.
    home.file =
      lib.mkIf (cfg.writeMode == "home.file")
      (builtins.mapAttrs
        (logical: entry: mkHomeFileEntry logical entry)
        (lib.mapAttrs' (logical: entry: {
            name = "${resolvedProjectsRoot}/${logical}";
            value = entry;
          })
          structures));

    home.activation.agentProjectConfigs =
      lib.mkIf (cfg.writeMode == "activation")
      (dag.entryAfter ["writeBoundary"] ''
        $DRY_RUN_CMD ${pkgs.python3}/bin/python3 ${../../../../scripts/project-configs-salt.py} ${lib.escapeShellArgs generatorArgs}
      '');
  }
  // {
    options.${namespace}.bookmarks.projects = {
      projectsRoot = mkOption {
        type = types.nullOr (types.either types.str types.path);
        default = null;
        description = ''
          Root of the Syncthing-synced projects tree. When null, resolved from
          `services.syncthing.settings.folders.<syncthingFolderName>.path`,
          falling back to `$HOME/Projects`.
        '';
      };

      rutubeProjectsRelativePath = mkOption {
        type = types.str;
        default = "--professional/Rutube__";
        description = ''
          `rutubeProjectsRoot` relative to `projectsRoot`. Also the default
          logical prefix for projects, which keeps the Syncthing ignore list
          independent of the host-specific absolute root.
        '';
      };

      rutubeProjectsRoot = mkOption {
        type = types.str;
        default = "${resolvedProjectsRoot}/${cfg.rutubeProjectsRelativePath}";
        description = "Root of the Rutube project suites inside `projectsRoot`.";
      };

      smugRoot = mkOption {
        type = types.str;
        default = "${rutubeProjectsRoot}/_configs/Smug__";
        description = "Root of the Smug worktree config trees.";
      };

      nixConfigsRoot = mkOption {
        type = types.str;
        default = "${rutubeProjectsRoot}/_configs/Nix__";
        description = "Root of the per-suite Nix config trees.";
      };

      scriptsRoot = mkOption {
        type = types.str;
        default = "${rutubeProjectsRoot}/_scripts";
        description = "Source `_scripts` tree linked into every project.";
      };

      projects = mkOption {
        type = types.listOf (types.submodule ({config, ...}: {
          options = {
            suiteName = mkOption {
              type = types.str;
              description = "Project suite name (also the Smug/Nix config directory).";
            };
            path = mkOption {
              type = types.str;
              description = "Absolute project path inside `projectsRoot`.";
            };
            logicalPath = mkOption {
              type = types.str;
              default = projectLogicalPath {
                projectsRoot = resolvedProjectsRoot;
                projectPath = config.path;
              };
              description = ''
                Project path relative to `projectsRoot`. The default project list
                carries an explicit logical path (so the Syncthing boundary does
                not depend on the host root); a custom project derives it from
                `path` unless set explicitly.
              '';
            };
            worktrees = mkOption {
              type = types.listOf types.str;
              default = cfg.worktrees;
              description = "Worktrees for this project; defaults to the global list.";
            };
          };
        }));
        default = defaultProjects {
          rutubeProjectsRoot = rutubeProjectsRoot;
          relativePrefix = cfg.rutubeProjectsRelativePath;
        };
        description = "Project suites to generate configs for.";
      };

      worktrees = mkOption {
        type = types.listOf types.str;
        default = defaultWorktrees;
        description = "Default worktree names used for `_configs/*.yml` and `*/.envrc`.";
      };

      generationRoot = mkOption {
        type = types.str;
        default = "${config.home.homeDirectory}/.local/share/agent-project-configs";
        description = ''
          Host-local, outside the synced tree. Mirrors the logical project tree;
          contains real dereferenced files, never absolute store symlinks.
        '';
      };

      manifestPath = mkOption {
        type = types.str;
        default = "${config.home.homeDirectory}/.local/state/agent-project-configs/manifest.json";
        description = "Manifest written atomically by the salt generator (schema 1).";
      };

      writeMode = mkOption {
        type = types.enum ["home.file" "activation"];
        default = "home.file";
        description = ''
          `home.file` preserves the Darwin out-of-store link behavior.
          `activation` installs the salt generator after `writeBoundary`.
        '';
      };

      writeLinks = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Replace the generated project paths with salt-local links into the
          generation root. Always gated on the effective Syncthing ignore
          boundary; the generator fails closed with
          `PROJECT_CONFIG_IGNORE_MISSING` when it cannot verify it.
        '';
      };

      prune = mkOption {
        type = types.bool;
        default = true;
        description = "Prune generation-root paths that are no longer in the model.";
      };

      ignoreBoundaryFile = mkOption {
        type = types.nullOr (types.either types.str types.path);
        default = null;
        description = ''
          File containing the effective Syncthing ignore patterns, one per line
          (for example the output of `syncthing cli config folders <id> ignores get`).
          Required at runtime when `writeLinks = true` unless a command is set.
        '';
      };

      ignoreBoundaryCommand = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Shell command that prints the effective Syncthing ignore patterns to
          stdout, one per line. Used only when `ignoreBoundaryFile` is null.
        '';
      };

      syncthingFolderName = mkOption {
        type = types.str;
        default = "rut-Projects";
        description = "Syncthing folder whose path and ignore boundary this module follows.";
      };

      ignorePatterns = mkOption {
        type = types.listOf types.str;
        default = projectIgnorePatterns;
        readOnly = true;
        description = ''
          Tier 1 `rut-Projects` ignore patterns derived from the same model as
          the generated paths. Appended by the Syncthing home modules.
        '';
      };

      generatorPayloadPath = mkOption {
        type = types.str;
        default = toString generatorPayloadFile;
        readOnly = true;
        internal = true;
        description = "Store path of the generator JSON payload (for Make targets).";
      };
    };
  }
