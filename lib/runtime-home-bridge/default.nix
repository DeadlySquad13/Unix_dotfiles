{
  namespace,
  inputs,
  lib,
  ...
}: let
  inherit (inputs.nixpkgs.lib) concatMapAttrs listToAttrs nameValuePair toJSON;
in {
  # Host-specific runtime-home-bridge catalogs. Pure data; the system side
  # feeds them into the bridge service and the home side derives bookmark
  # resolutions from them. Serialized to JSON via `catalogJsonContent` as the
  # interchange contract so the system, the home and future augmenters all
  # consume one artifact.
  catalogs.darkGreen-tangerineDream = {
    namespaceRoot = "/usr/local/darkGreen-/tangerineDream";
    zNamespaceRoot = "/ztangerineDream";
    variants = rec {
      base = [
        { source = "_cache/opencode"; target = ".cache/opencode"; }
        { source = "_cache/opencode__node_modules"; target = ".config/opencode/node_modules"; }
        { source = "_state/opencode"; target = ".local/state/opencode"; }
        { source = "_share/opencode"; target = ".local/share/opencode"; }
      ];
      baseForSwitch = [
        # darkGreen-tangerineDream is intended to be deployed and then
        # switched. We need these mounts specifically during switching (on
        # previous step they were present at a host system so weren't
        # required in a docker filesystem).
        {
          zSource = "shared-/@salt/Projects";
          source = "Projects";
          target = ".bookmarks/projects";
        }
      ] ++ base;
      orchestrator = [
        { source = "_configs/Unix_dotfiles"; target = ".bookmarks/shared-configs/Unix_dotfiles"; }
      ] ++ baseForSwitch;
      convPlatProv = [
        { source = "_configs"; target = ".bookmarks/shared-configs"; }
        { source = "_scripts"; target = ".bookmarks/shared-scripts"; }
      ] ++ baseForSwitch;
      full = [
        { source = "_configs"; target = ".bookmarks/shared-configs"; }
        { source = "_scripts"; target = ".bookmarks/shared-scripts"; }
        {
          zSource = "shared-/@salt/shared-/Projects";
          source = "shared-Projects";
          target = ".bookmarks/shared-projects";
        }
      ] ++ baseForSwitch;
    };
  };

  catalogs.darkGreen-tangerineDream-green = {
    namespaceRoot = "/usr/local/darkGreen-/tangerineDream-green";
    zNamespaceRoot = "/ztangerineDream-green";
    variants = rec {
      base = [
        { source = "_cache/opencode"; target = ".cache/opencode"; }
        { source = "_cache/opencode__node_modules"; target = ".config/opencode/node_modules"; }
        { source = "_state/opencode"; target = ".local/state/opencode"; }
        { source = "_share/opencode"; target = ".local/share/opencode"; }
      ];
      green = [
        { source = "_configs"; target = ".bookmarks/shared-configs"; }
        { source = "_scripts"; target = ".bookmarks/shared-scripts"; }
        {
          zSource = "shared-/@salt/Projects";
          source = "Projects";
          target = ".bookmarks/projects";
        }
      ] ++ base;
    };
  };

  # JSON interchange contract for a catalog. Both the system-side bridge and
  # the home-side consumers derive the identical store artifact from this, so
  # augmentations on either side stay in sync as long as they go through the
  # same catalog data.
  catalogJsonContent = { homeDirectory }: catalog:
    toJSON {
      version = 1;
      inherit homeDirectory;
      inherit (catalog) namespaceRoot zNamespaceRoot variants;
    };

  # Map every bridge link target (relative to the home directory) to its fully
  # resolved, symlink-free real path, across all variants. Keys are absolute so
  # they match what `resolveBookmarks` normalizes `~/.bookmarks/<x>` into.
  mkResolutions = { homeDirectory, catalog }:
    concatMapAttrs (_variant: mappings:
      listToAttrs (map (m:
        nameValuePair "${homeDirectory}/${m.target}" (
          if (m.zSource or "") != "" then "${catalog.zNamespaceRoot}/${m.zSource}"
          else "${catalog.namespaceRoot}/${m.source}"
        )) mappings)
    ) catalog.variants;
}
