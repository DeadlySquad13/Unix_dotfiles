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
  text = ''exec -a ${pkgs.telegram-desktop}/bin/Telegram ${nixGLNvidia}/bin/${nixGLNvidia.name} ${pkgs.telegram-desktop}/bin/Telegram "$@"'';
  meta.priority = (pkgs.telegram-desktop.meta.priority or 5) - 1;
}
