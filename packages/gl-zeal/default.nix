# Source: https://github.com/NixOS/nixpkgs/pull/297473
{
  writeShellApplication,
  pkgs,
}:
let nixGLNvidia = pkgs.nixgl.auto.nixGLNvidia;
in
writeShellApplication {
  name = "gl-zeal";
  runtimeInputs = [
    pkgs.zeal
    nixGLNvidia
    # pkgs.nixgl.nixGLCommon
  ];
  # text = ''exec -a zeal nixGLNvidia-555.58.02 zeal "$@"'';
  text = ''exec -a zeal ${nixGLNvidia}/bin/${nixGLNvidia.name} zeal "$@"'';
  meta.priority = (pkgs.zeal.meta.priority or 5) - 1;
}
