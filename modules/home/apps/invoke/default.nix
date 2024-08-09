{ pkgs, ... }:

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
