{
  writeShellApplication,
  pkgs,
}: let
  nixGLNvidia = pkgs.nixgl.auto.nixGLNvidia;
in
  writeShellApplication {
    name = "obsidian";
    runtimeInputs = [
      pkgs.obsidian
      nixGLNvidia
    ];
    text = ''exec -a obsidian ${nixGLNvidia}/bin/${nixGLNvidia.name} obsidian "$@"'';
    meta.priority = (pkgs.obsidian.meta.priority or 5) - 1;
  }
