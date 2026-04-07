{
  writeShellApplication,
  pkgs,
}:
let nixGLNvidia = pkgs.nixgl.auto.nixGLNvidia;
in
writeShellApplication {
  name = "gl-neovide";
  runtimeInputs = [
    pkgs.neovide
    nixGLNvidia
  ];
  text = ''exec -a neovide ${nixGLNvidia}/bin/${nixGLNvidia.name} neovide "$@"'';
  meta.priority = (pkgs.neovide.meta.priority or 5) - 1;
}
