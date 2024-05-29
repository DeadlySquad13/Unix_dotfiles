{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nodejs_21
    # pkgs.node-18_x.pkgs.pnpm
    corepack_21
  ];
}
