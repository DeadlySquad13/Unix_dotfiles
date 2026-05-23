{
  # Snowfall Lib provides a customized `lib` instance with access to your flake's library
  # as well as the libraries available from your flake's inputs.
  lib,
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
  imports = [
    "${toString <nixpkgs>}/nixos/modules/profiles/qemu-guest.nix"
    "${toString <nixpkgs>}/nixos/modules/installer/scan/not-detected.nix"
    "${builtins.fetchTarball "https://github.com/nix-community/disko/archive/master.tar.gz"}/module.nix"
    inputs.xray-config.nixosModules.xray-disko
    inputs.xray-config.nixosModules.system-module
    inputs.xray-config.nixosModules.xray-module
  ];

  networking.hostName = lib.mkForce "MelisStoke";

  /*
     snowfallorg.user = {
    enable = true;
    name = "ds-omega";
  };
  */

  # Already set in base module
  # system = {
    # This value determines the Home Manager release that your configuration is
    # compatible with. This helps avoid breakage when a new Home Manager release
    # introduces backwards incompatible changes.
    #
    # You should not change this value, even if you update Home Manager. If you do
    # want to update the value, then make sure to first check the Home Manager
    # release notes.
  #   stateVersion = "24.11";
  # };

  xray = {
    # It's actually at secrets/MelisStoke/buildTime-/xray-config.json, just encrypted.
    # See `decrypt-build-time-secrets` target at `Makefile`.
    configFile = ~/.bookmarks/Unix_dotfiles/secrets/tmp/MelisStoke/xray-config.json;
    rootAuthorizedKeysFile = ~/.ssh/Lent__MelisStoke.pub;
    userAuthorizedKeysFile = ~/.ssh/Lent__MelisStoke.pub;
  };
  services.dbus.implementation = lib.mkForce "broker";
  environment.systemPackages = with pkgs; [
    cowsay
  ];

  nix.settings = {
    trusted-users = [
      "root"
      "@wheel"
    ];
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  lib.ds-omega = {
    modules = {
      ecosystem = {
        enable = false;

        nix = disabled;
      };
      development = {
        enable = false;
      };
      xserver = {
        enable = false;
      };
      services = {
        enable = false;

        yandex-disk = disabled;
      };
      system-services = {
        enable = false;

        awesomewm = {
          enabled = false;
          dev = false;
          stage = false;
          prod = false;
        };
      };
    };
  };
}
