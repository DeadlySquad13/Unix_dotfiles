{
  inputs,
  writeShellApplication,
  pkgs,
  lib,
}: let
  inherit (lib.ds-omega) mkIfLinux;
  inherit (lib) mkIf;

  nixGLNvidia = pkgs.nixgl.auto.nixGLNvidia;
  pkgs-stable = import inputs.nixpkgs-stable {
    config.permittedInsecurePackages = [
      "electron-27.3.11"
    ];
  };
  logseq = pkgs-stable.logseq;
in
  writeShellApplication {
    name = "logseq";
    runtimeInputs = [
      logseq
      nixGLNvidia
    ];
    runtimeEnv = mkIf (mkIfLinux {}) {
      # To fix logseq "Open with default app" on Linux without desktop manager.
      # see: https://github.com/logseq/logseq/issues/11462
      XDG_CURRENT_DESKTOP = "GNOME";
    };
    text = ''exec -a logseq ${nixGLNvidia}/bin/${nixGLNvidia.name} logseq "$@"'';
    meta.priority = (logseq.meta.priority or 5) - 1;
  }
