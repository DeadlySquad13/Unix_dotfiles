{
  writeShellApplication,
  pkgs,
}:
let nixGLNvidia = pkgs.nixgl.auto.nixGLNvidia;
in
writeShellApplication {
  name = "gl-tor-browser";
  runtimeInputs = [
    pkgs.tor-browser
    nixGLNvidia
  ];
  text = ''exec -a tor-browser ${nixGLNvidia}/bin/${nixGLNvidia.name} tor-browser "$@"'';
  meta.priority = (pkgs.tor-browser.meta.priority or 5) - 1;
}
