{
  lib,
  writeShellScriptBin,
}: let
  neovim-dev = writeShellScriptBin "nvim-dev" ''
    #!/usr/bin/env bash
    NVIM_APPNAME=nvim-dev nvim "$@"
  '';
in
  neovim-dev
