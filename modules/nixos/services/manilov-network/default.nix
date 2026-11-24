{
  config,
  lib,
  pkgs,
  options,
  ...
}: let
  cfg = config.services.manilov-network;

  profiles = import ./profiles.nix;

  # The package definition lives next to the module so the module never has to
  # spell out a path into `packages/`; `applier.nix` owns that one relative
  # import. Snowfall also exposes the same derivation as
  # `pkgs.ds-omega.manilov-network`, which is what a host actually installs.
  applier = import ./applier.nix {inherit pkgs;};

  markerSchema = "manilov.network.marker/v1";

  selectorFor = profile: {
    schema = markerSchema;
    inherit profile;
    role = "owner";
    owner = {
      kind = "image";
      id = cfg.imageId;
    };
  };

  digestOf = selector: "sha256:" + builtins.hashString "sha256" (builtins.toJSON selector);

  serviceEnvironment = {
    MANILOV_IMAGE_ID = cfg.imageId;
    MANILOV_CONFIRM_DEADLINE = toString cfg.confirmDeadline;
    MANILOV_MAX_CONFIRM_DEADLINE = toString cfg.maxConfirmDeadline;
    MANILOV_ALLOWED_SELECTORS = builtins.toJSON cfg.allowedSelectors;
  };

  applyCommand = lib.escapeShellArgs [
    "${cfg.package}/bin/manilov-network"
    "apply"
    "--marker"
    cfg.markerPath
    "--state-dir"
    cfg.stateDir
  ];

  rollbackCommand = lib.escapeShellArgs [
    "${cfg.package}/bin/manilov-network"
    "rollback"
    "--reason"
    "auto"
    "--marker"
    cfg.markerPath
    "--state-dir"
    cfg.stateDir
  ];

  watchdogCommand = lib.escapeShellArgs [
    "${cfg.package}/bin/manilov-network"
    "watchdog"
    "--marker"
    cfg.markerPath
    "--state-dir"
    cfg.stateDir
  ];
in
  lib.ds-omega.mkIfEnabled
  {
    inherit config;
    category = "services";
    name = "manilov-network";
    extraPredicate = { module-cfg, ... }: module-cfg ? enable;
  }
  {
    services.manilov-network.enable = true;

    assertions = [
      {
        assertion = cfg.confirmDeadline <= cfg.maxConfirmDeadline;
        message = "services.manilov-network.confirmDeadline (${toString cfg.confirmDeadline}) must be less than or equal to services.manilov-network.maxConfirmDeadline (${toString cfg.maxConfirmDeadline}).";
      }
      {
        # The marker, not the NixOS module, owns profile selection and host
        # identity. Keep these names out of the module option set so a host
        # cannot silently pin a policy that the image would ignore.
        assertion =
          !(options.services.manilov-network ? buildProfile)
          && !(options.services.manilov-network ? activeProfile)
          && !(options.services.manilov-network ? defaultProfile)
          && !(options.services.manilov-network ? mode)
          && !(options.services.manilov-network ? hostName);
        message = "services.manilov-network must not declare buildProfile, activeProfile, defaultProfile, mode, or hostName; the marker owns profile selection and host identity.";
      }
    ];

    boot.kernelModules = ["tun"];
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

    systemd.services.manilov-network = {
      description = "Manilov VM network datapath (marker-selected profile)";
      wantedBy = ["multi-user.target"];
      after = ["network-pre.target"];
      before = ["network.target"] ++ lib.optional cfg.libvirt.enable "libvirtd.service";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = applyCommand;
        ExecStop = rollbackCommand;
        StateDirectory = "manilov-network";
        RuntimeDirectory = "manilov-network";
      };
      environment = serviceEnvironment;
    };

    systemd.services.manilov-network-watchdog = {
      description = "Manilov VM network datapath health watchdog";
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = watchdogCommand;
      };
      environment = serviceEnvironment;
    };

    systemd.timers.manilov-network-watchdog = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = cfg.watchdogInterval;
        Persistent = false;
      };
    };

    virtualisation.libvirtd.enable = cfg.libvirt.enable;
    # Root-owned qcow2 images and libvirt state must stay readable when the
    # datapath module brings libvirt up inside the container.
    virtualisation.libvirtd.qemu.runAsRoot = cfg.libvirt.enable;

    environment.etc."manilov/profiles.json".text = builtins.toJSON {
      version = 1;
      inherit (cfg) profiles;
    };
  }
  // {
    options.services.manilov-network = {
      enable = lib.mkEnableOption "the Manilov network marker/applier service";

      imageId = lib.mkOption {
        type = lib.types.str;
        default = "nikolaigogol";
        description = "Image identity written into the owner selector and matched against the host marker.";
      };

      applierVersion = lib.mkOption {
        type = lib.types.str;
        default = "1.0.0";
        description = "Version of the Manilov network applier contract implemented by this image.";
      };

      markerPath = lib.mkOption {
        type = lib.types.str;
        default = "/etc/manilov/marker.json";
        description = "Absolute path of the host-provisioned marker consumed by the applier.";
      };

      stateDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/manilov-network";
        description = "Absolute durable state directory for the Manilov network owner.";
      };

      runtimeDir = lib.mkOption {
        type = lib.types.str;
        default = "/run/manilov-network";
        description = "Absolute per-boot runtime directory for locks and ephemeral state.";
      };

      hostNetworkdView = lib.mkOption {
        type = lib.types.str;
        default = "/run/manilov-network/host-networkd";
        description = "Absolute path where the host systemd-networkd view is exposed to the applier.";
      };

      watchdogInterval = lib.mkOption {
        type = lib.types.str;
        default = "30s";
        description = "systemd time span between watchdog checks of the confirmed datapath.";
      };

      confirmDeadline = lib.mkOption {
        type = lib.types.int;
        default = 300;
        description = "Seconds the applier waits for confirmation before arming the deadman.";
      };

      maxConfirmDeadline = lib.mkOption {
        type = lib.types.int;
        default = 900;
        description = "Upper bound, in seconds, accepted for confirmDeadline.";
      };

      healthProbe = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether the applier runs datapath health probes after apply.";
      };

      libvirt = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether the applier also reconciles libvirt VM tap attachment state.";
        };
      };

      profiles = lib.mkOption {
        type = lib.types.attrs;
        readOnly = true;
        default = profiles;
        description = "Read-only op catalog for the proxyarp and bridge datapath profiles.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        default = applier.manilov-network;
        description = "Read-only applier package (also exposed as pkgs.ds-omega.manilov-network).";
      };

      allowedSelectors = lib.mkOption {
        type = lib.types.attrs;
        readOnly = true;
        default = lib.mapAttrs (
          profile: _: let
            selector = selectorFor profile;
          in
            selector // {selectorDigest = digestOf selector;}
        )
        cfg.profiles;
        description = "Read-only marker selectors this image is allowed to own, keyed by profile.";
      };

      effective = lib.mkOption {
        type = lib.types.attrs;
        readOnly = true;
        default = {
          inherit (cfg) imageId confirmDeadline maxConfirmDeadline;
          profiles = cfg.profiles;
        };
        description = "Read-only summary of the effective image-side Manilov network contract.";
      };

      modulePath = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = toString ./.;
        description = "Absolute path of this module directory.";
      };
    };
  }
