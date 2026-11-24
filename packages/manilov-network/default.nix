{
  writeShellApplication,
  pkgs,
}: let
  # The op catalog is owned by the NixOS module. Embedding its JSON keeps the
  # applier self-contained (no runtime read of /etc) while still making
  # profiles.nix the single source of truth.
  profiles = import ../../modules/nixos/services/manilov-network/profiles.nix;
  profilesJson = builtins.toJSON profiles;
in
  writeShellApplication {
    name = "manilov-network";

    runtimeInputs = with pkgs; [
      iproute2
      nftables
      jq
      coreutils
      gnugrep
      gawk
      util-linux
      systemd
    ];

    text =
      ''
        # shellcheck disable=SC2016
        readonly MANILOV_PROFILES_JSON=${pkgs.lib.escapeShellArg profilesJson}
      ''
      + builtins.readFile ./manilov-network.sh;
  }
