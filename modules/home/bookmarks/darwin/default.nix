{ config, lib, namespace, ... }:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "bookmarks";
  name = "darwin";
  extraPredicate = lib.${namespace}.mkIfDarwin;
}
{
  home.file = builtins.mapAttrs
    (name: value: { source = config.lib.file.mkOutOfStoreSymlink value; })
    (
      lib.attrsets.concatMapAttrs (name: value: { ".bookmarks/${name}" = value; } )
      (
        {
          "ChronoIndex" = ~/ChronoIndex;
        }
      )
    );
}
