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
  # These are build-time inputs: the config is decrypted by
  # `make decrypt-build-time-secrets NODE=MelisStoke` and the public keys live
  # on the deploying machine. They are absent on a fresh checkout / CI host, so
  # only import the xray modules when every file they read at evaluation time
  # actually exists.
  xrayConfigPath = ~/.bookmarks/Unix_dotfiles/secrets/tmp/MelisStoke/xray-config.json;
  xrayRootKeysPath = ~/.ssh/Lent__MelisStoke.pub;
  xrayUserKeysPath = ~/.ssh/Lent__MelisStoke.pub;
  hasXrayConfig =
    builtins.pathExists xrayConfigPath
    && builtins.pathExists xrayRootKeysPath
    && builtins.pathExists xrayUserKeysPath;
in {
  imports = [
    "${toString <nixpkgs>}/nixos/modules/profiles/qemu-guest.nix"
    "${toString <nixpkgs>}/nixos/modules/installer/scan/not-detected.nix"
    "${builtins.fetchTarball "https://github.com/nix-community/disko/archive/master.tar.gz"}/module.nix"
    inputs.xray-config.nixosModules.xray-disko
  ] ++ lib.optionals hasXrayConfig [
    inputs.xray-config.nixosModules.system-module
    inputs.xray-config.nixosModules.xray-module
  ];

  warnings = lib.optional (!hasXrayConfig) ''
    MelisStoke: xray is omitted because its build-time configuration and/or
    SSH public keys are not present. Decrypt
    secrets/buildTime-/MelisStoke/xray-config.json with
    `make decrypt-build-time-secrets NODE=MelisStoke` and ensure the
    Lent__MelisStoke SSH public key exists, then re-evaluate.
  '';

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
// lib.optionalAttrs hasXrayConfig {
  xray = {
    # It's actually at secrets/MelisStoke/buildTime-/xray-config.json, just encrypted.
    # See `decrypt-build-time-secrets` target at `Makefile`.
    configFile = xrayConfigPath;
    rootAuthorizedKeysFile = xrayRootKeysPath;
    userAuthorizedKeysFile = xrayUserKeysPath;
  };
}
