{
  writeShellApplication,
  pkgs,
}:
let nixGLNvidia = pkgs.nixgl.auto.nixGLNvidia;
in
writeShellApplication {
  name = "gl-telegram-desktop";
  runtimeInputs = [
    pkgs.telegram-desktop
    nixGLNvidia
  ];
  text = ''exec -a telegram-desktop ${nixGLNvidia}/bin/${nixGLNvidia.name} telegram-desktop "$@"'';
  meta.priority = (pkgs.telegram-desktop.meta.priority or 5) - 1;
}
