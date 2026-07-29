{
  # Snowfall Lib provides a customized `lib` instance with access to your flake's library
  # as well as the libraries available from your flake's inputs.
  lib,
  # An instance of `pkgs` with your overlays and packages applied is also available.
  pkgs,
  # You also have access to your flake's inputs.
  # inputs,
  # Additional metadata is provided by Snowfall Lib.
  namespace, # The namespace used for your flake, defaulting to "internal" if not set.
  # home, # The home architecture for this host (eg. `x86_64-linux`).
  # target, # The Snowfall Lib target for this home (eg. `x86_64-home`).
  # format, # A normalized name for the home target (eg. `home`).
  # virtual, # A boolean to determine whether this home is a virtual target using nixos-generators.
  # host, # The host name for this home.
  # All other arguments come from the home home.
  # config,
  ...
}: let
  inherit (lib.${namespace}) disabled;
in {
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

  environment.systemPackages = with pkgs; [
    # Testing.
    cowsay
    lolcat
  ];

  # Take priority over generated value (tangerineDream_inner).
  networking = {
    hostName = lib.mkDefault "darkGreen-tangerineDream";
  };

  # programs.ssh.startAgent = true;
  users.users.tangerineDream = {
    isNormalUser = true;
    home = "/home/tangerineDream";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    #initialPassword = "test";
    password = "test";
    description = "Main admin user";
    # openssh.authorizedKeys.keyFiles = [
    # authorizedkeys file.
    # ];
  };

  boot = {
    isContainer = true;

    # Load TUN/TAP kernel module for virtual networking
    kernelModules = ["tun"];

    # Enable IP forwarding (required for routing between interfaces)
    kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
    };
  };

  services.sshd.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  lib.ds-omega = {
    modules = {
      ecosystem = {
        enable = false;

        nix = disabled;
      };
      development = {
        enable = true;
      };
    };
  };

  virtualisation = {
    libvirtd = {
      enable = true;
      # Used for UEFI boot of Home Assistant OS guest image
      qemu = {
        runAsRoot = true;
      };
      # qemuOvmf = true;
    };
  };
}
