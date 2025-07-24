# Source: https://github.com/NixOS/nixpkgs/pull/297473
{
  writeShellApplication,
  pkgs,
}:
let nixGLNvidia = pkgs.nixgl.auto.nixGLNvidia;
in
writeShellApplication {
  name = "ferdium";
  runtimeInputs = [
    pkgs.ferdium
    nixGLNvidia
    # pkgs.nixgl.nixGLCommon
  ];
  # text = ''exec -a ferdium nixGLNvidia-555.58.02 ferdium "$@"'';
  text = ''exec -a ferdium ${nixGLNvidia}/bin/${nixGLNvidia.name} ferdium "$@"'';
  meta.priority = (pkgs.ferdium.meta.priority or 5) - 1;
}
