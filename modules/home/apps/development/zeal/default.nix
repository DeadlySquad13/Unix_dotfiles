# { lib, pkgs, config, ... }:
# let nixGL = import ../../nixGL/default.nix { inherit pkgs config; };
# in
# {
#   home.packages = with pkgs; [
#     (nixGL zeal)
#   ];
# }
# { config, pkgs, ... }:
# let inherit ((pkgs.callPackage ''
#   ${builtins.fetchTarball {
#       url = "https://github.com/guibou/nixGL/archive/17c1ec63b969472555514533569004e5f31a921f.tar.gz";
#       sha256 = "0yh8zq746djazjvlspgyy1hvppaynbqrdqpgk447iygkpkp3f5qr";
#     }}/nixGL.nix'' {})) nixGLIntel;
# in
# {
#   programs.qutebrowser = {
#     enable = true;
#     keyBindings = {
#       normal = {
#         "m" = "spawn mpv {url}";
#       };
#     };
#     package =
#       pkgs.writeShellScriptBin "qutebrowser" ''
#            #!/bin/sh
#            ${nixGLIntel}/bin/nixGLIntel ${pkgs.qutebrowser}/bin/qutebrowser "$@"
#         '';
#   };
# }
{
  pkgs,
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "development";
  name = "zeal";
}
{
  home.packages = with pkgs; [
    # writeShellScriptBin
    # "zeal"
    # ''
    #   #!/bin/sh

    #   ${nixgl.nixGLIntel}/bin/nixGL ${zeal}/bin/zeal "$@"
    # ''
    ds-omega.gl-zeal
  ];
}
