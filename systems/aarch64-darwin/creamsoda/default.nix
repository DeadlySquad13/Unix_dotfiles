{
  # Snowfall Lib provides a customized `lib` instance with access to your flake's library
  # as well as the libraries available from your flake's inputs.
  lib,
  darwin,
  # An instance of `pkgs` with your overlays and packages applied is also available.
  pkgs,
  # You also have access to your flake's inputs.
  inputs,
  # Additional metadata is provided by Snowfall Lib.
  namespace, # The namespace used for your flake, defaulting to "internal" if not set.
  home, # The home architecture for this host (eg. `x86_64-linux`).
  target, # The Snowfall Lib target for this home (eg. `x86_64-home`).
  format, # A normalized name for the home target (eg. `home`).
  virtual, # A boolean to determine whether this home is a virtual target using nixos-generators.
  host, # The host name for this home.
  # All other arguments come from the home home.
  config,
  ...
}: let
  inherit (lib.${namespace}) disabled enabled;
in {
  /* snowfallorg.user = {
    enable = true;
    name = "ds-omega";
  }; */

  /* home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  }; */


 /* The value is used to conditionalize
       backwards‐incompatible changes in default settings. You should
       usually set this once when installing nix-darwin on a new system
       and then never change it (at least without reading all the relevant
       entries in the changelog using `darwin-rebuild changelog`). */
  system.stateVersion = 5;

  system.defaults.dock = {
    autohide = true;
    orientation = "bottom";

    # Customize Hot Corners.
    # wvous-tl-corner = 2;  # top-left - Mission Control
    # wvous-tr-corner = 13; # top-right - Lock Screen
    wvous-bl-corner = 10;  # bottom-left - Put Display to Sleep
    wvous-br-corner = 13;  # bottom-right - Lock Screen
  };

  lib.ds-omega = {

    modules = {
      ecosystem = {
        enable = false;

        nix = disabled;
      };
    };
  };
}
