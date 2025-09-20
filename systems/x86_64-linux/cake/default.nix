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

  sops = {
    # age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt"; # must have no password!
    age.keyFile = "/home/ds13/.config/sops/age/keys.txt"; # must have no password!
    # # REFACTOR: Targeting root of Unix_dotfiles.
    defaultSopsFile = ../../../secrets/secrets.yaml;
    secrets = {
      glab_DeadlySquad13_token = {
        #   sopsFile = ../../../../../secrets/secrets.yaml; # optionally define per-secret files

        #   # %r gets replaced with a runtime directory, use %% to specify a '%'
        #   # sign. Runtime dir is $XDG_RUNTIME_DIR on linux and $(getconf
        #   # DARWIN_USER_TEMP_DIR) on darwin.
        # path = "%r/test.txt";
      };

      cake_ds13_password = {};
      "wireless.secretsFile" = {};
    };
  };
  sops.secrets.cake_ds13_password.neededForUsers = true;
  users.mutableUsers = false;

  networking = {
    hostId = "37564573";
    hostName = "cake";

    wireless = {
      enable = true;
      # `ext:` prefix mark special variable of a wpa that is read from secrets file.
      secretsFile = config.sops.secrets."wireless.secretsFile".path;
      networks.DS13_5G.pskRaw = "ext:DS13_5G_psk";
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
    hashedPasswordFile = config.sops.secrets.cake_ds13_password.path;
    description = "Main admin user";
    # openssh.authorizedKeys.keyFiles = [
      # authorizedkeys file.
    # ];
  };
  users.users.admin = {
    isNormalUser  = true;
    home  = "/home/admin";
    extraGroups  = [ "wheel" ];
    hashedPasswordFile = config.sops.secrets.cake_ds13_password.path;
    description = "Emergency admin user";
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
