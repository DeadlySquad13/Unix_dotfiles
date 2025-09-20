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
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    "${builtins.fetchTarball "https://github.com/nix-community/disko/archive/master.tar.gz"}/module.nix"
    ./disk-config.nix
  ];

  /*
     snowfallorg.user = {
    enable = true;
    name = "ds-omega";
  };
  */

  /*
     home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  };
  */
  system = {
    # This value determines the Home Manager release that your configuration is
    # compatible with. This helps avoid breakage when a new Home Manager release
    # introduces backwards incompatible changes.
    #
    # You should not change this value, even if you update Home Manager. If you do
    # want to update the value, then make sure to first check the Home Manager
    # release notes.
    stateVersion = "24.11";
  };

  boot = {
    loader = {
      systemd-boot.enable = true; # (for UEFI systems only)
      efi.canTouchEfiVariables = true;
    };

    supportedFilesystems = [ "zfs" ];
    kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
  };

  networking = {
    hostId = "37564573";
    hostName = "cake";

    wireless = {
      enable = true;
      networks."DS13_5G".psk = config.sops.secrets.DS13_5G_password.path;
      extraConfig = "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=wheel";
    };
    networkmanager.enable = false;
  };

  # I don't like this setting, but it's hard to use deploy-rs without it.
  home-manager.backupFileExtension = "backup";

  # programs.ssh.startAgent = true;
  users.users.ds13 = {
    isNormalUser  = true;
    home  = "/home/ds13";
    extraGroups  = [ "wheel" ];
    #initialPassword = "test";
    password = config.sops.secrets.cake_ds13_password.path;
    description = "Main admin user";
    # openssh.authorizedKeys.keyFiles = [
      # authorizedkeys file.
    # ];
  };

  services.sshd.enable = true;

  nix.settings = {
    trusted-users = [ "root" "@wheel" ];
    experimental-features = [ "nix-command" "flakes" ];
  };

  lib.ds-omega = {
    modules = {
      ecosystem = {
        enable = false;

        nix = disabled;
      };
      development = {
        enable = true;
      };
      services = {
        enable = true;
      };
      system-services = {
        enable = true;

        awesomewm = {
          enabled = true;
          dev = false;
          stage = false;
          prod = true;
        };
      };
    };
  };
}
