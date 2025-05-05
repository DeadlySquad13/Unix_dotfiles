{
  lib,
  writeShellScriptBin,
}: let
  neovim-stage = writeShellScriptBin "nvim-stage" ''
    #!/usr/bin/env bash
    NVIM_APPNAME=nvim-stage nvim "$@"
  '';
in
  neovim-stage
