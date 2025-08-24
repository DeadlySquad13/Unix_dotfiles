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
  name = "logseq";
}
{
  home.packages = with pkgs; [
    ds-omega.gl-logseq
  ];
  # Very similar to obsidian.
  # Needed for web clipper on Linux.
  # There's very similar entry in [source code](https://github.com/NixOS/nixpkgs/blob/20075955deac2583bb12f07151c2df830ef346b4/pkgs/by-name/lo/logseq/package.nix#L267C3-L267C15)
  # but it doesn't work. Maybe my gl overlay ruins it...
  xdg.desktopEntries.logesq = {
      name = "Logseq";
      desktopName = "Logseq";
      exec = "logseq %U";
      terminal = false;
      icon = "logseq";
      startupWMClass = "Logseq";
      comment = "A privacy-first, open-source platform for knowledge management and collaboration.";
      mimeType = [ "x-scheme-handler/logseq" ];
      categories = [ "Utility" ];
  };
}
