# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL

{ config, lib, pkgs, home-manager, ... }:

#let
#  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
#in
{
  imports = [
    # include NixOS-WSL modules
    <nixos-wsl/modules>
    #(import "${home-manager}/nixos")
    #home-manager.nixosModules.default
    # ./hardware-configuration.nix
  ];

  # https://nix-community.github.io/NixOS-WSL/options.html
  wsl = {
    enable = true;
    defaultUser = "ds13";

    # docker-desktop.enable = true;
  };

  # boot.loader.systemd-boot.enable = true; # (for UEFI systems only)
  # services.sshd.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # programs.ssh.startAgent = true;
  users.users.ds13 = rec {
    isNormalUser = true;
    home = "/home/ds13";
    description = "Main admin user";
    extraGroups = [ "wheel" ];
    # openssh.authorizedKeys.keyFiles = [
    	# authorizedkeys file.
    # ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

  home-manager.users.ds13 = { pkgs, ... }: {
    home.packages = with pkgs; [ bat ];
    # programs.bash.enable = true;

    #home.stateVersion = "24.11";
  };
}
