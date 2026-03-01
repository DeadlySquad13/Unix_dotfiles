{
  # pkgs,
  lib,
  inputs,
  namespace,
  config,
  ...
}: let
  # TODO: Remove once build error is fixed. Must be ok next time we update
  # flake inputs.
  pkgs-stable = import inputs.nixpkgs-stable {
    config.permittedInsecurePackages = [
      "electron-27.3.11"
    ];
  };
in
  lib.${namespace}.mkIfEnabled
  {
    inherit config;
    category = "development";
    name = "deno";
  }
  {
    home.packages = with pkgs-stable; [
      deno
    ];
  }
