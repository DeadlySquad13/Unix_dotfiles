{
  pkgs,
  lib,
  namespace,
  inputs,
  ...
}: let
  # Repo `lib/paths` is not reachable through the check's injected `lib.ds-omega`
  # namespace (the existing checks mock the namespace manually). Import it
  # directly, providing the module args it needs. `lib/paths` only reads
  # `lib.${namespace}.disabled/enabled` for its own top-level `inherit`; it never
  # uses them, so a minimal mock suffices.
  pathsLib = import ../../lib/paths {
    inherit inputs;
    inherit namespace;
    lib = lib // {
      ${namespace} = {
        disabled = { enable = false; };
        enabled = { enable = true; };
      };
    };
  };

  inherit (pathsLib) get-path resolveRuntimePaths;

  homeDirectory = "/home/testuser";
  empty = { };

  # --- Unit tests for `resolveRuntimePaths` ---

  # 1. A `~/.bookmarks` string that is registered resolves to the real path.
  assertProjectsResolved =
    (resolveRuntimePaths {
        inherit homeDirectory;
        resolutions = {
          "/home/testuser/.bookmarks/projects" = "/ztangerineDream/shared-/@salt/Projects";
        };
      }
      {
        projects = "~/.bookmarks/projects";
      })
    .projects
    == "/ztangerineDream/shared-/@salt/Projects";

  # 2. Multiple keys resolve independently.
  assertMultipleResolved =
    (resolveRuntimePaths {
        inherit homeDirectory;
        resolutions = {
          "/home/testuser/.bookmarks/projects" = "/ztangerineDream/shared-/@salt/Projects";
          "/home/testuser/.bookmarks/shared-configs" = "/usr/local/darkGreen-/tangerineDream/_configs";
        };
      }
      {
        projects = "~/.bookmarks/projects";
        shared-configs = "~/.bookmarks/shared-configs";
      })
    == {
      projects = "/ztangerineDream/shared-/@salt/Projects";
      shared-configs = "/usr/local/darkGreen-/tangerineDream/_configs";
    };

  # 3. Non-bridge `.bookmarks` keys pass through unchanged, even in the presence
  #    of other resolved keys. Only keys present in the runtime-bridge
  #    resolutions table are rewritten (this is what prevents wrongly rewriting
  #    home-manager bookmarks like `kbd`/`shared-configs`).
  assertNonBridgeKeyPassesThrough =
    let
      r = resolveRuntimePaths {
        inherit homeDirectory;
        resolutions = {
          "/home/testuser/.bookmarks/projects" = "/ztangerineDream/shared-/@salt/Projects";
        };
      }
      {
        projects = "~/.bookmarks/projects";
        shared-configs = "~/.bookmarks/shared-configs"; # NOT in bridge table
        kbd = "~/.bookmarks/kbn"; # NOT in bridge table
      };
    in
      r.projects == "/ztangerineDream/shared-/@salt/Projects"
      && r.shared-configs == "~/.bookmarks/shared-configs"
      && r.kbd == "~/.bookmarks/kbn";

  # 3b. With an empty resolutions table nothing resolves.
  assertEmptyResolutions =
    (resolveRuntimePaths {
        inherit homeDirectory;
        resolutions = empty;
      }
      {
        kbd = "~/.bookmarks/kbn";
      })
    .kbd
    == "~/.bookmarks/kbn";

  # 4. Nix path literals (store-copy semantics) pass through unchanged.
  assertNixPathUnchanged = let
    src = ./.;
    result = (resolveRuntimePaths {
        inherit homeDirectory;
        resolutions = empty;
      }
      { inherit src; })
    .src;
  in
    builtins.isPath result && toString result == toString src;

  # --- Unit tests for `get-path` ---

  mockConfig = paths: {
    home.homeDirectory = homeDirectory;
    lib.${namespace}.paths = paths;
  };

  # `as-string = true`: returns the `~`-expanded path as a string.
  assertGetPathString =
    builtins.toString
    (get-path {
      config = mockConfig { projects = "~/.bookmarks/projects"; };
      cb = p: p.projects;
      as-string = true;
    })
    == "/home/testuser/.bookmarks/projects";

  # `as-string = false` (default): returns a path (for store copy), not a string.
  assertGetPathStore = let
    result = get-path {
      config = mockConfig { scripts = "/home"; };
      cb = p: p.scripts;
    };
  in
    builtins.isPath result && toString result == "/home";

in
  assert assertProjectsResolved;
  assert assertMultipleResolved;
  assert assertNonBridgeKeyPassesThrough;
  assert assertEmptyResolutions;
  assert assertNixPathUnchanged;
  assert assertGetPathString;
  assert assertGetPathStore;
  pkgs.runCommand "test-paths" { } ''
    echo "paths unit tests OK" > "$out"
  ''
