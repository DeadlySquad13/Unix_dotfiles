{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nodejs_22
    # pkgs.node-18_x.pkgs.pnpm
    corepack_22
  ];
}
