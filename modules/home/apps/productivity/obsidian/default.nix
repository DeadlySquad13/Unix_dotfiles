{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "productivity";
  name = "obsidian";
}
{
  home.packages = with pkgs; [
    obsidian
  ];
  # Needed for [web clipper](https://help.obsidian.md/web-clipper/troubleshoot#Obsidian+does+not+open) on Linux.
  # There's very similar entry in [source code](https://github.com/NixOS/nixpkgs/blob/20075955deac2583bb12f07151c2df830ef346b4/pkgs/by-name/ob/obsidian/package.nix#L49)
  # but it doesn't work. Maybe my gl overlay ruins it...
  xdg.desktopEntries.obsidian = {
    name = "obsidian";
    comment = "Knowledge base";
    icon = "obsidian";
    exec = "obsidian %u";
    categories = [ "Office" ];
    mimeType = [ "x-scheme-handler/obsidian" ];
  };
}
