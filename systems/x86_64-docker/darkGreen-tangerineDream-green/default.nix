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
    ./apps/ecosystem/sops-npmjs/default.nix
    ./apps/ecosystem/sops-opencode/default.nix
    ./services/runtime-home-bridge/default.nix
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

  # Volumes mounted by docker compose live in the per-system namespace below.
  # The container runs `/init` as root and docker pre-creates missing mount-point
  # dirs as root:root; the bind mounts themselves appear root-owned (fuse
  # user_id=0), so mode bits are the only access control that works for the
  # unprivileged user. Runs before home-manager, so symlinks can be created into
  # these dirs during user activation. Additive chmod never removes permissions.
  #
  # Ported from the `ai-/darkGreen-/tangerineDream-green` copypaste (ADR 0006
  # Phase 0 / ADR 0007) before that copy is replaced by the mergeable child repo.
  # WARN: Breaks container activation: it seems to create a certain delay after /init and before bash become available.
  # Because of that we can't start container in our scripts automatically,
  # container has to be polled. Overall, seems like a hack that should be
  # implemented via runtime-home-bridge.
  # system.activationScripts.fixDockerMountPermissions = lib.stringAfter [
  #   "users"
  #   "groups"
  # ] ''
  #   ns=/usr/local/darkGreen-/tangerineDream-green

  #   # Namespace dirs + every mount-point parent: traversable and writable by all.
  #   for d in \
  #     "$ns" "$ns/_configs" "$ns/_scripts" "$ns/Projects" "$ns/Projects/--personal" \
  #     "$ns/_state" "$ns/_state/opencode" "$ns/_share" "$ns/_share/opencode"; do
  #     mkdir -p "$d"
  #     chmod 0777 "$d"
  #   done

  #   # Mounted configs/scripts: add world read/write so the user can read files
  #   # regardless of the FUSE root-mapping. Skip mounts that aren't present.
  #   chmod -R a+rwX "$ns/_configs/Unix_dotfiles" "$ns/_scripts" 2>/dev/null || true

  #   # Docker-created intermediate dirs under the home (ephemeral container layer)
  #   # must be writable so home-manager can create symlinks into them.
  #   chmod 0777 /home/tangerineDream-green/Projects \
  #              /home/tangerineDream-green/Projects/--personal 2>/dev/null || true
  # '';

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
        sops-npmjs = enabled;
      };
      development = {
        enable = true;
      };

      services = {
        enable = false;
        runtime-home-bridge = enabled;
      };
    };
  };
}
