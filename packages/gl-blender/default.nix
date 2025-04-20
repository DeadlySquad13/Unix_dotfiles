{
  writeShellApplication,
  pkgs,
}:
let nixGLNvidia = pkgs.nixgl.auto.nixGLNvidia;
in
writeShellApplication {
  name = "gl-blender";
  runtimeInputs = [
    pkgs.blender
    nixGLNvidia
  ];
  text = ''exec -a blender ${nixGLNvidia}/bin/${nixGLNvidia.name} blender "$@"'';
  meta.priority = (pkgs.blender.meta.priority or 5) - 1;
}
