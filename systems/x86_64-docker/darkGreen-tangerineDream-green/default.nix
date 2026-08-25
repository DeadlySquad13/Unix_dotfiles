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
  # REFACTOR: Implement auto-import via Snowfall-lib utils.
  imports = [
    ./apps/ecosystem/sops-opencode/default.nix
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

  /*
  systemd.services.docker-setup = {
    description = "Docker container setup commands";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "tangerineDream-green";
      ExecStart = "${pkgs.bash}/bin/bash -c 'cd /home/tangerineDream-green/.bookmarks/shared-configs/Unix_dotfiles/ && echo \"test\" | make switch-$${SYSTEM_NAME}-system'";
      Environment = [
        "SYSTEM_NAME=darkGreen-tangerineDream-green"
      ];
      RemainAfterExit = true;
    };
  };
  */
  networking.hostName = "darkGreen-tangerineDream-green";

  services.runtime-home-bridge = {
    enable = true;
    user = "tangerineDream-green";
    homeDirectory = "/home/tangerineDream-green";
    namespaceRoot = "/usr/local/darkGreen-/tangerineDream-green";
    required = true;
    variants = {
      green = [
        { source = "_configs"; target = ".bookmarks/shared-configs"; }
        { source = "_scripts"; target = ".bookmarks/shared-scripts"; }
        { source = "Projects/--personal/AiAssistance__"; target = "Projects/--personal/AiAssistance__"; }
        { source = "_state/opencode"; target = ".local/state/opencode"; }
        { source = "_share/opencode"; target = ".local/share/opencode"; }
      ];
    };
  };

  # programs.ssh.startAgent = true;
  users.users.tangerineDream-green = {
    isNormalUser = true;
    home = "/home/tangerineDream-green";
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

  # boot.loader.systemd-boot.enable = true; # (for UEFI systems only)
  services.sshd.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  lib.ds-omega = {
    common = {
      # For resolving docker mounts -> inner filesystem.
      spiceNamespace = "darkGreen";
      systemBaseName = "tangerineDream-green";
    };

    paths = {
      # STYLE: Name our paths properly.
      system = "/usr/local/";
    };

    modules = {
      ai-assistance = {
        enable = true;
      };
      ecosystem = {
        enable = false;

        nix = disabled;
        sops = enabled;
        sops-opencode = enabled;
      };
      development = {
        enable = true;
      };
    };
  };
}
