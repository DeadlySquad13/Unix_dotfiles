{
  pkgs,
  lib,
  namespace,
  inputs,
  ...
}: let
  # Integration test: the bookmark-resolution pipeline end to end. It mirrors
  # how docker hosts like `darkGreen-tangerineDream` wire their `paths` through
  # `resolveBookmarks` against the runtime-home-bridge catalog, and asserts the
  # resolved values are symlink-free real paths a Nix path context can consume.

  # Import the two repo libs directly (they are not exposed through the check's
  # injected namespace; see the `paths` check for the rationale).
  pathsLib = import ../../lib/paths {
    inherit inputs namespace;
    lib = lib // {
      ${namespace} = {
        disabled = { enable = false; };
        enabled = { enable = true; };
      };
    };
  };
  bridgeLib = import ../../lib/runtime-home-bridge {
    inherit inputs namespace;
    lib = lib // {
      ${namespace} = {
        disabled = { enable = false; };
        enabled = { enable = true; };
      };
    };
  };

  inherit (pathsLib) resolveRuntimePaths;
  inherit (bridgeLib) catalogs mkResolutions;

  homeDirectory = "/home/tangerineDream";

  # The catalog entry for this host, exactly as the system set of the docker
  # host consumes it.
  catalog = catalogs.darkGreen-tangerineDream;

  resolutions =
    (mkResolutions {
      inherit homeDirectory;
      inherit catalog;
    })."/home/tangerineDream/.bookmarks/projects";

  # A realistic `paths` set like the inner home's.
  resolved = resolveRuntimePaths {
    inherit homeDirectory;
    resolutions = mkResolutions { inherit homeDirectory; inherit catalog; };
  } {
    projects = "~/.bookmarks/projects";
    shared-configs = "~/.bookmarks/shared-configs";
    shared-scripts = "~/.bookmarks/shared-scripts";
    kbd = "~/.bookmarks/kbn"; # unregistered -> passes through
  };

  # The resolved `projects` must be the zSource target (the build-time real path).
  assertProjectsResolved = resolved.projects == "/ztangerineDream/shared-/@salt/Projects";
  # `shared-configs` comes from the `convPlatProv`/`full` variant.
  assertSharedConfigsResolved = resolved.shared-configs == "/usr/local/darkGreen-/tangerineDream/_configs";
  assertSharedScriptsResolved = resolved.shared-scripts == "/usr/local/darkGreen-/tangerineDream/_scripts";
  # Unregistered keys pass through unchanged (still the `.bookmarks` string).
  assertKbdUnchanged = resolved.kbd == "~/.bookmarks/kbn";
  # The catalog resolution record itself must be non-empty and path-like.
  assertCatalogResolution = builtins.isString resolutions && builtins.stringLength resolutions > 0;
in
  assert assertProjectsResolved;
  assert assertSharedConfigsResolved;
  assert assertSharedScriptsResolved;
  assert assertKbdUnchanged;
  assert assertCatalogResolution;
  pkgs.runCommand "test-bookmarks" { } ''
    echo "bookmarks integration OK: ${resolved.projects}" > "$out"
  ''
