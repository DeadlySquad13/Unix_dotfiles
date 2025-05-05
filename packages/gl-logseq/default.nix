{
  inputs,
  writeShellApplication,
  pkgs,
}:
let
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
  text = ''exec -a logseq ${nixGLNvidia}/bin/${nixGLNvidia.name} logseq "$@"'';
  meta.priority = (logseq.meta.priority or 5) - 1;
}
