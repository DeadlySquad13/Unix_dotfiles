{
  writeShellApplication,
  pkgs,
}:
let nixGLNvidia = pkgs.nixgl.auto.nixGLNvidia;
in
writeShellApplication {
  name = "gl-zotero";
  runtimeInputs = [
    pkgs.zotero
    nixGLNvidia
  ];
  text = ''exec -a zotero ${nixGLNvidia}/bin/${nixGLNvidia.name} zotero "$@"'';
  meta.priority = (pkgs.zotero.meta.priority or 5) - 1;
}
