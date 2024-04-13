{
  description = "NixOS configuration";

  inputs = {
    nixpkgs = {
        url = "github:NixOS/nixpkgs/nixpkgs-23.11-darwin";
    };
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    snowfall-lib = {
        url = "github:snowfallorg/lib";
        inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # outputs = inputs:
  #   inputs.snowfall-lib.mkFlake {
  #     # You must provide our flake inputs to Snowfall Lib.
  #     inherit inputs;

  #     # The `src` must be the root of the flake. See configuration
  #     # in the next section for information on how you can move your
  #     # Nix files to a separate directory.
  #     src = ./.;
  # };
  outputs = { self, nixpkgs, home-manager, ... }@inputs: let
    inherit (self) outputs;
  in {
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          #./hosts/buddha.nix
          #./modules
	  ./configuration.nix
          #{ nixpkgs.config.allowUnfree = true; }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.ds13 = import ./home-manager/default.nix;
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
        ];
      };
    };
    homeConfigurations = {
      "ds13@salt" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {inherit inputs outputs;};
        # system = "x86_64-linux";
        modules = [
          # ./home-manager/default.nix
          ./home.nix
          #./hosts/buddha.nix
          #./modules
          # ./configuration.nix
          #{ nixpkgs.config.allowUnfree = true; { nixpkgs.config.allowUnsupportedSystem = true; }}
          # home-manager.nixosModules.home-manager
          # {
          #   home-manager.useGlobalPkgs = true;
          #   home-manager.useUserPackages = true;
          #   home-manager.users.ds13 = import ./home-manager/default.nix;
          #   home-manager.extraSpecialArgs = { inherit inputs; };
          # }
        ];
      };

      "aspakalo" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-darwin; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {inherit inputs outputs;};
        # system = "x86_64-linux";
        modules = [
          # ./home-manager/default.nix
          ./home-darwin.nix
          #./hosts/buddha.nix
          #./modules
          # ./configuration.nix
          #{ nixpkgs.config.allowUnfree = true; }
          # home-manager.nixosModules.home-manager
          # {
          #   home-manager.useGlobalPkgs = true;
          #   home-manager.useUserPackages = true;
          #   home-manager.users.ds13 = import ./home-manager/default.nix;
          #   home-manager.extraSpecialArgs = { inherit inputs; };
          # }
        ];
      };
    };
  };
}

