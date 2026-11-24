# Package wiring for the Manilov network applier.
#
# Keeping the `callPackage` relative path here (rather than in the module body)
# means `default.nix` only imports a sibling module file and never has to know
# where `packages/` lives. Snowfall exposes the same derivation through
# `pkgs.ds-omega.manilov-network`.
{pkgs, ...}: {
  manilov-network = pkgs.callPackage ../../../../packages/manilov-network {};
}
