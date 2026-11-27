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
          # Capture the dependency list so the check can assert ordering; the
          # real Home Manager DAG stores the same `{ after; data; }` shape.
          config.lib.dag.entryAfter = names: text: {after = names; data = text;};
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
  saltNoStignore = evalHome {
    projectsRoot = saltRoot;
    extra = {
      config.${namespace}.bookmarks.projects = {
        writeMode = "activation";
        writeStignore = false;
        generationRoot = "/home/ds13/.local/share/agent-project-configs";
        manifestPath = "/home/ds13/.local/state/agent-project-configs/manifest.json";
      };
    };
  };

  darwinFiles = darwin.config.home.file;
  saltActivation = salt.config.home.activation.agentProjectConfigs or null;
  saltStignore = salt.config.home.activation.agentProjectConfigsStignore or null;
  saltProjects = salt.config.${namespace}.bookmarks.projects;
  saltIgnore = saltProjects.ignorePatterns;
  saltStignorePatterns = saltProjects.stignoreBasePatterns ++ saltIgnore;

  # Exact argv strings, not per-pattern substrings: `/x` is a prefix of `/x/y`,
  # so `hasInfix pattern` would still pass if `/x`'s own argument were dropped
  # while a longer sibling containing it remained.
  # `generatorArgs` embeds the payload store path, so its escaped form carries
  # string context; `hasInfix` operates on plain strings. The comparison is
  # textual only, so dropping context is correct and safe.
  stignoreArgString =
    builtins.unsafeDiscardStringContext (lib.escapeShellArgs saltProjects.stignoreArgs);
  generatorArgString =
    builtins.unsafeDiscardStringContext (lib.escapeShellArgs saltProjects.generatorArgs);

  expectedIgnorePatterns =
    map (logical: "/" + logical) (builtins.attrNames saltStructures);

  libSource = builtins.readFile ../../lib/project-configs/default.nix;

  # Regression guard: the Home Manager Syncthing module silently drops
  # `settings.folders.<name>.ignorePatterns`, so this feature owns
  # `<root>/.stignore` instead. Other folders (rut-Documents) legitimately
  # declare their own `ignorePatterns` for the NixOS-style path, so the guard
  # is scoped to the `rut-Projects` entry this module drives.
  creamSyncthing = builtins.readFile "${../../homes/aarch64-darwin}/apakalo@creamsoda/syncthing/default.nix";
  saltSyncthing = builtins.readFile "${../../homes/x86_64-linux}/ds13@salt/syncthing/default.nix";

  syncthingFolderBlock = folder: text: let
    parts = lib.splitString "\"${folder}\" = {" text;
  in
    if builtins.length parts < 2
    then ""
    else lib.head (lib.splitString "};" (builtins.elemAt parts 1));

  # Drop everything after `#` so explanatory comments that mention the dropped
  # attribute do not trip the guard. The files under test contain no `#` inside
  # string literals.
  stripComments = text:
    lib.concatMapStrings
    (line: lib.head (lib.splitString "#" line) + "\n")
    (lib.splitString "\n" text);

  rutProjectsBlock = folder: text:
    stripComments (syncthingFolderBlock folder text);

  creamRutProjects = rutProjectsBlock "rut-Projects" creamSyncthing;
  saltRutProjects = rutProjectsBlock "rut-Projects" saltSyncthing;

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

  # 4. `activation` mode writes no `home.file` and installs the generator,
  #    ordered after the `.stignore` writer.
  assertActivation =
    salt.config.home.file == {}
    && saltActivation != null
    && saltActivation.after == ["writeBoundary" "agentProjectConfigsStignore"]
    && lib.hasInfix "project-configs-salt.py" saltActivation.data
    && lib.hasInfix generatorArgString (builtins.unsafeDiscardStringContext saltActivation.data);

  # 4a. The stignore writer is installed with the script path and the *whole*
  #     argument string (every base plus derived pattern, in order). Comparing
  #     the escaped argv rules out the prefix-collision that per-pattern
  #     `hasInfix` allowed.
  assertStignoreActivation =
    saltStignore != null
    && lib.hasInfix "stignore-merge.py" saltStignore.data
    && lib.hasInfix stignoreArgString (builtins.unsafeDiscardStringContext saltStignore.data);

  # 4b. `ignoreBoundaryFile` defaults to `<projectsRoot>/.stignore`.
  assertStignoreBoundaryDefault =
    toString saltProjects.ignoreBoundaryFile == "${saltRoot}/.stignore";

  # 4c. Disabling the writer removes the activation entry and the boundary
  #     default.
  assertStignoreDisabled =
    !(saltNoStignore.config.home.activation ? agentProjectConfigsStignore)
    && saltNoStignore.config.${namespace}.bookmarks.projects.ignoreBoundaryFile
    == null;

  # 5. Tier 1 ignore patterns are derived from the exact same model, one per
  #    generated logical path, and never absolute paths.
  assertIgnoreCoverage =
    lib.sort (a: b: a < b) saltIgnore
    == lib.sort (a: b: a < b) (projectConfigs.ignorePatterns saltStructures)
    && builtins.length saltIgnore == builtins.length (builtins.attrNames saltStructures)
    && lib.all (pattern: lib.hasPrefix "/--professional/Rutube__/" pattern) saltIgnore;

  # 5a. `ignorePatterns` is exactly one root-anchored pattern per logical path,
  #     unique, and free of `//`.
  assertIgnorePatternsExact =
    saltIgnore == expectedIgnorePatterns
    && lib.all (pattern: lib.hasPrefix "/" pattern) saltIgnore
    && lib.all (pattern: !(lib.hasInfix "//" pattern)) saltIgnore
    && lib.unique saltIgnore == saltIgnore;

  # 5b. Explicit per-logical-path membership, not just whole-list equality.
  assertIgnorePerPath =
    lib.all
    (logical: builtins.elem "/${logical}" saltIgnore)
    (builtins.attrNames saltStructures);

  # 5c. Base and derived patterns never collide.
  assertNoDuplicateStignorePatterns =
    builtins.length saltStignorePatterns
    == builtins.length (lib.unique saltStignorePatterns);

  # 4d. Activation ordering, the writer flag, and the owned path.
  assertStignoreShape =
    saltStignore != null
    && saltStignore.after == ["writeBoundary"]
    && saltProjects.writeStignore == true
    && toString saltProjects.stignorePath == "${saltRoot}/.stignore";

  # 4e. The Syncthing host files never re-declare `ignorePatterns` on the
  #     `rut-Projects` folder (Home Manager would silently drop it).
  assertNoSyncthingIgnorePatterns =
    creamRutProjects != ""
    && saltRutProjects != ""
    && !(lib.hasInfix "ignorePatterns" creamRutProjects)
    && !(lib.hasInfix "ignorePatterns" saltRutProjects);

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
  assert assertStignoreActivation;
  assert assertStignoreBoundaryDefault;
  assert assertStignoreDisabled;
  assert assertIgnorePatternsExact;
  assert assertIgnorePerPath;
  assert assertNoDuplicateStignorePatterns;
  assert assertStignoreShape;
  assert assertNoSyncthingIgnorePatterns;
  assert assertIgnoreCoverage;
  assert assertLogicalPathsRelative;
  assert assertNoCurrentSystem;
  assert assertNoHostLiterals;
  assert assertEntryShapes;
  pkgs.runCommand "test-project-configs" {} ''
    echo "project-configs unit tests OK: ${toString (builtins.length (builtins.attrNames saltStructures))} logical paths" > "$out"
  ''
