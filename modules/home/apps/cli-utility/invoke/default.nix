{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "cli-utility";
  name = "invoke";
}
{
  home.packages = with pkgs; [
    python311Packages.invoke
  ];

  programs.bash = {
    shellAliases = {
        i = "invoke --search-root ~/.bookmarks/shared-scripts";
    };
  };
}
