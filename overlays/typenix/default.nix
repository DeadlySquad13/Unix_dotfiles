{
  channels,
  inputs,
  lib,
  ...
}: final: prev: {
  inherit (inputs.typenix.packages.${builtins.currentSystem}) typenix;
}
