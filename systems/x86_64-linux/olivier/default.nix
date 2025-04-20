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

  imports = [
    # include NixOS-WSL modules
    <nixos-wsl/modules>
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

  networking.hostName = "olivier";

  # https://nix-community.github.io/NixOS-WSL/options.html
  wsl = {
    enable = true;
    # Had to configure it properly:
    # https://discourse.nixos.org/t/set-default-user-in-wsl2-nixos-distro/38328
    # https://nix-community.github.io/NixOS-WSL/how-to/change-username.html
    defaultUser = "ds13";

    docker-desktop.enable = true;
  };

  # programs.ssh.startAgent = true;
  users.users.ds13 = {
    isNormalUser  = true;
    home  = "/home/ds13";
    extraGroups  = [ "wheel" "networkmanager" ];
    #initialPassword = "test";
    password = "test";
    description = "Main admin user";
    # openssh.authorizedKeys.keyFiles = [
      # authorizedkeys file.
    # ];
  };

  # boot.loader.systemd-boot.enable = true; # (for UEFI systems only)
  services.sshd.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  lib.ds-omega = {
    modules = {
      ecosystem = {
        enable = false;

        nix = disabled;
      };
      development = {
        enable = true;
      };
    };
  };
}
