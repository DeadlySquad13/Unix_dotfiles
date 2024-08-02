{ pkgs, ... }:

{
  home.packages = with pkgs; [
    eza
  ];

  home.shellAliases = {
    ll = "eza -lagh --time-style=long-iso --group-directories-first --icons";
  };
}
