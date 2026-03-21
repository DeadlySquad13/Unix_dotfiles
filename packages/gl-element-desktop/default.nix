{
  writeShellApplication,
  pkgs,
}:
let nixGLNvidia = pkgs.nixgl.auto.nixGLNvidia;
in
writeShellApplication {
  name = "gl-element-desktop";
  runtimeInputs = [
    pkgs.element-desktop
    nixGLNvidia
  ];
  text = ''exec -a element-desktop ${nixGLNvidia}/bin/${nixGLNvidia.name} element-desktop "$@"'';
  meta.priority = (pkgs.element-desktop.meta.priority or 5) - 1;
}
