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

    # For virt-install.
    virt-manager
    # FileSystem shared volume between host and vm (@NikolaiGogol_inner).
    virtiofsd

    # For lsusb.
    usbutils
  ];

  # Take priority over generated value (NikolaiGogol_inner).
  networking = {
    hostName = lib.mkDefault "NikolaiGogol";

    # TAP device for VM networking (created declaratively by NixOS)
    interfaces.tap0 = {
      virtual = true;
      virtualType = "tap";
      ipv4.routes = [
        { address = "192.168.31.200"; prefixLength = 32; }
      ];
      # Respond to ARP from VM for gateway 192.168.31.1
      proxyARP = true;
    };

    # Proxy ARP on Wi-Fi interface — pseudo-bridge for WLAN
    interfaces.wlan0.proxyARP = true;

    # Firewall: allow forwarding between TAP and Wi-Fi (no NAT needed)
    firewall = {
      enable = true;
      extraCommands = ''
        iptables -A FORWARD -i tap0 -o wlan0 -j ACCEPT
        iptables -A FORWARD -i wlan0 -o tap0 -j ACCEPT
        iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
      '';
    };
  };

  # programs.ssh.startAgent = true;
  users.users.ds13 = {
    isNormalUser = true;
    home = "/home/ds13";
    extraGroups = [
      "wheel"
      "networkmanager"
      # Access to libvirtd.
      "libvirtd"
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
