{
  writeShellApplication,
  pkgs,
}:
let nixGLNvidia = pkgs.nixgl.auto.nixGLNvidia;
in
writeShellApplication {
  name = "gl-mscore";
  runtimeInputs = [
    pkgs.musescore
    nixGLNvidia
  ];
  text = ''exec -a mscore ${nixGLNvidia}/bin/${nixGLNvidia.name} mscore "$@"'';
  meta.priority = (pkgs.musescore.meta.priority or 5) - 1;
}
