{
  pkgs,
  lib,
  namespace,
  inputs,
  ...
}: let
  # The repo lib is not injected into a standalone check's `lib`, so import the
  # model directly (same convention as `checks/paths` and `checks/bookmarks`).
  projectConfigs = import ../../lib/project-configs {inherit lib;};

  modulesLib = import ../../lib/modules {
    inherit inputs namespace;
    lib =
      lib
      // {
        ${namespace} = {
          disabled = {enable = false;};
          enabled = {enable = true;};
        };
      };
  };

  libWithNamespace =
    lib
    // {
      ${namespace} = {
        inherit (modulesLib) mkIfEnabled;
        inherit
          (projectConfigs)
          defaultProjects
          defaultWorktrees
          ignorePatterns
          projectStructures
          ;
      };
    };

  pkgsStub =
    pkgs
    // {
      writeText = name: text: builtins.toFile name text;
      python3 = "/fake-python3";
    };

  # Darwin-like fixture: absolute paths under $HOME, Smug suite dirs absent so
  # the model uses the shared `-gitWorktrees` fallback.
  darwinRoot = "/Users/example/Projects";
  saltRoot = "/zsalt/shared-/@creamsoda/Projects";

  structuresFor = projectsRoot:
    projectConfigs.projectStructures {
      inherit projectsRoot;
      rutubeProjectsRoot = "${projectsRoot}/--professional/Rutube__";
      pathIsDirectory = _: false;
    };

  darwinStructures = structuresFor darwinRoot;
  saltStructures = structuresFor saltRoot;

  evalHome = {
    projectsRoot,
    extra ? {},
  }:
    lib.evalModules {
      specialArgs = {
        inherit namespace;
        lib = libWithNamespace;
        pkgs = pkgsStub;
      };
      modules = [
        ../../modules/home/bookmarks/projects/default.nix
        {
          options.home.homeDirectory = lib.mkOption {type = lib.types.str;};
          options.home.file = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = {};
          };
          options.home.activation = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = {};
          };
          options.assertions = lib.mkOption {
            type = lib.types.listOf lib.types.anything;
            default = [];
          };
          options.services.syncthing.settings.folders = lib.mkOption {
            type = lib.types.attrs;
            default = {};
          };
          options.lib = lib.mkOption {
            type = lib.types.attrs;
            default = {};
          };

          config.home.homeDirectory = "/Users/example";
          config.lib.${namespace}.modules = {
            bookmarks = {
              enable = true;
              projects.enable = true;
            };
          };
          config.lib.file.mkOutOfStoreSymlink = path: "out-of-store:${toString path}";
          config.lib.dag.entryAfter = _names: text: text;
          config.services.syncthing.settings.folders."rut-Projects".path = projectsRoot;
        }
        extra
      ];
    };

  darwin = evalHome {projectsRoot = darwinRoot;};
  salt = evalHome {
    projectsRoot = saltRoot;
    extra = {
      config.${namespace}.bookmarks.projects = {
        writeMode = "activation";
        generationRoot = "/home/ds13/.local/share/agent-project-configs";
        manifestPath = "/home/ds13/.local/state/agent-project-configs/manifest.json";
      };
    };
  };

  darwinFiles = darwin.config.home.file;
  saltActivation = salt.config.home.activation.agentProjectConfigs or null;
  saltIgnore = salt.config.${namespace}.bookmarks.projects.ignorePatterns;

  libSource = builtins.readFile ../../lib/project-configs/default.nix;

  # --- assertions ---

  # 1. Determinism: identical inputs produce identical logical paths/entries.
  assertDeterministic =
    structuresFor darwinRoot == darwinStructures
    && structuresFor saltRoot == saltStructures;

  # 2. Darwin keeps the out-of-store link shape (absolute $HOME key).
  autoHubMainKey = "${darwinRoot}/--professional/Rutube__/AutoHub/_configs/Main.yml";
  assertDarwinFileShape =
    darwinFiles ? ${autoHubMainKey}
    && darwinFiles.${autoHubMainKey}.recursive == true
    && darwinFiles.${autoHubMainKey}.source
    == "out-of-store:${darwinRoot}/--professional/Rutube__/_configs/Smug__/-gitWorktrees/Main.yml";

  # 3. Text entries remain literal `text` files on Darwin.
  autoHubEnvrcKey = "${darwinRoot}/--professional/Rutube__/AutoHub/.envrc";
  assertDarwinTextShape =
    darwinFiles ? ${autoHubEnvrcKey}
    && lib.hasInfix "dotenv ./.env.dev" darwinFiles.${autoHubEnvrcKey}.text;

  # 4. `activation` mode writes no `home.file` and installs the generator.
  assertActivation =
    salt.config.home.file == {}
    && saltActivation != null
    && lib.hasInfix "project-configs-salt.py" saltActivation
    && lib.hasInfix "--input" saltActivation;

  # 5. Tier 1 ignore patterns are derived from the exact same model, one per
  #    generated logical path, and never absolute paths.
  assertIgnoreCoverage =
    lib.sort (a: b: a < b) saltIgnore
    == lib.sort (a: b: a < b) (projectConfigs.ignorePatterns saltStructures)
    && builtins.length saltIgnore == builtins.length (builtins.attrNames saltStructures)
    && lib.all (pattern: lib.hasPrefix "/--professional/Rutube__/" pattern) saltIgnore;

  # 6. Logical paths are host-neutral (relative to projectsRoot): salt-like
  #    inputs do not leak the salt prefix into the model keys.
  assertLogicalPathsRelative =
    lib.all (path: !(lib.hasPrefix "/" path)) (builtins.attrNames saltStructures);

  # 7. Static purity: no evaluation-host platform check and no host paths in
  #    shared code.
  assertNoCurrentSystem = !(lib.hasInfix "currentSystem" libSource);
  assertNoHostLiterals =
    !(lib.hasInfix "/Users/" libSource) && !(lib.hasInfix "/zsalt/" libSource);

  # 8. Every file/dir entry has a source; every text entry has text.
  assertEntryShapes =
    lib.all (
      entry:
        if entry.kind == "text"
        then entry ? text && !(entry ? source)
        else entry ? source && !(entry ? text)
    ) (builtins.attrValues saltStructures);
in
  assert assertDeterministic;
  assert assertDarwinFileShape;
  assert assertDarwinTextShape;
  assert assertActivation;
  assert assertIgnoreCoverage;
  assert assertLogicalPathsRelative;
  assert assertNoCurrentSystem;
  assert assertNoHostLiterals;
  assert assertEntryShapes;
  pkgs.runCommand "test-project-configs" {} ''
    echo "project-configs unit tests OK: ${toString (builtins.length (builtins.attrNames saltStructures))} logical paths" > "$out"
  ''
