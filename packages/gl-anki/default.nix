{
  writeShellApplication,
  pkgs,
}:
let nixGLNvidia = pkgs.nixgl.auto.nixGLNvidia;
in
writeShellApplication {
  name = "gl-anki";
  runtimeInputs = [
    pkgs.anki
    nixGLNvidia
  ];
  text = ''exec -a anki ${nixGLNvidia}/bin/${nixGLNvidia.name} anki "$@"'';
  meta.priority = (pkgs.anki.meta.priority or 5) - 1;
}
