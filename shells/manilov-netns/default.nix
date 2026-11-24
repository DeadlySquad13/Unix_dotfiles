{
  pkgs,
  ...
}: let
  # Build the applier into the shell so `tests/manilov/netns/run.sh` does not
  # need a working `nix` command inside the (network-isolated) harness.
  manilov-network = pkgs.callPackage ../../packages/manilov-network {};
in
  pkgs.mkShell {
    packages = with pkgs; [
      iproute2
      nftables
      jq
      bash
      coreutils
      gnugrep
      gnused
      util-linux
      # A real listening socket for the applier's `ss -ltn` health probe.
      socat
      manilov-network
    ];

    shellHook = ''
      echo "manilov netns harness: tests/manilov/netns/run.sh"
    '';
  }
