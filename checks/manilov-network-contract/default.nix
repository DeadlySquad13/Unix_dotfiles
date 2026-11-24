{
  pkgs,
  lib,
  ...
}: let
  # The module reads `lib.ds-omega.mkIfEnabled`; Snowfall injects that
  # namespaced lib in a real system. Here we mock it so the module body is
  # applied unconditionally, then merge the module's `//` options block (the
  # mock returns `{ config = <body>; }`, so the trailing `// { options = ...; }`
  # in the module still contributes options). This is the same pattern as
  # `checks/runtime-home-bridge-nixos`.
  mkIfEnabledMock = _opts: module: { config = module; };
  libWithNamespace = lib // {
    # Merge the real namespace first, then override the wrapper so a real
    # `mkIfEnabled` (which would read config.lib.ds-omega.modules and disable
    # the body) cannot win.
    ds-omega =
      (lib.ds-omega or {})
      // {
        disabled = {enable = false;};
        enabled = {enable = true;};
        mkIfEnabled = mkIfEnabledMock;
      };
  };

  node = lib.nixosSystem {
    inherit (pkgs.stdenv.hostPlatform) system;
    specialArgs = {lib = libWithNamespace;};
    modules = [
      ../../modules/nixos/services/manilov-network
      {
        system.stateVersion = "24.11";
        services.manilov-network.enable = true;
      }
    ];
  };

  cfg = node.config.services.manilov-network;
  profiles = cfg.profiles;
  allowed = cfg.allowedSelectors;
  service = node.config.systemd.services.manilov-network;
  watchdog = node.config.systemd.timers.manilov-network-watchdog;
  profilesText = node.config.environment.etc."manilov/profiles.json".text;
  profilesJson = builtins.fromJSON profilesText;
  opts = node.options.services.manilov-network;
in
  assert builtins.attrNames profiles == ["bridge" "proxyarp"];
  assert builtins.length profiles.proxyarp == 5;
  assert builtins.length profiles.bridge == 8;
  assert (builtins.head profiles.proxyarp).op == "link.add";
  assert (builtins.elemAt profiles.proxyarp 4).op == "nft.load";
  assert (builtins.head profiles.bridge).op == "assert.linkMac";
  assert (builtins.elemAt profiles.bridge 7).op == "nft.load";
  assert allowed.proxyarp.selectorDigest == "sha256:2970ce9648832ef0c40d32b1fa48ea775e8cfe35cc7645480695e52f6635ee57";
  assert allowed.bridge.selectorDigest == "sha256:a9211f72d9d7c3b19b0a4ef487d2a03da17802e03249832b76d14f82738ad527";
  assert !(service.serviceConfig ? ExecStartPost);
  assert lib.hasInfix "apply" service.serviceConfig.ExecStart;
  assert lib.hasInfix "rollback" service.serviceConfig.ExecStop;
  assert builtins.elem "network-pre.target" service.after;
  assert builtins.elem "network.target" service.before;
  assert watchdog.timerConfig.OnUnitActiveSec == "30s";
  assert profilesJson.version == 1;
  assert !(opts ? buildProfile);
  assert !(opts ? activeProfile);
  assert !(opts ? defaultProfile);
  assert !(opts ? mode);
  assert !(opts ? hostName);
  assert cfg.effective.confirmDeadline == 300;
  assert cfg.effective.maxConfirmDeadline == 900;
  pkgs.runCommand "manilov-network-contract" {
    nativeBuildInputs = [pkgs.jq];
  } ''
    printf '%s' ${lib.escapeShellArg profilesText} | jq -e '.version == 1' >/dev/null
    {
      echo "manilov-network contract OK"
      echo "profiles: ${lib.concatStringsSep ", " (builtins.attrNames profiles)}"
      echo "proxyarp ops: ${toString (builtins.length profiles.proxyarp)}"
      echo "bridge ops: ${toString (builtins.length profiles.bridge)}"
      echo "proxyarp selector: ${allowed.proxyarp.selectorDigest}"
      echo "bridge selector:   ${allowed.bridge.selectorDigest}"
      echo "timer OnUnitActiveSec: ${watchdog.timerConfig.OnUnitActiveSec}"
      echo "effective.confirmDeadline: ${toString cfg.effective.confirmDeadline}"
      echo "effective.maxConfirmDeadline: ${toString cfg.effective.maxConfirmDeadline}"
    } > "$out"
  ''
