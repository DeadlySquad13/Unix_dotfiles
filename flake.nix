{
  description = "NixOS configuration";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    };
    nixgl = {
      url = "github:nix-community/nixGL";
    };
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.snowfall-lib.mkFlake {
      # You must provide our flake inputs to Snowfall Lib.
      inherit inputs;

      # The `src` must be the root of the flake. See configuration
      # in the next section for information on how you can move your
      # Nix files to a separate directory.
      src = ./.;

      # 3rd party overlays.
      overlays = with inputs; [
        # Now you can reference pkgs.nixgl.nixGLNvidia and other wrappers.
        nixgl.overlay
      ];

      snowfall = {
        namespace = "ds-omega";

        meta = {
          name = "ds-omega-flake";

          title = "Unix dotfiles flake";
        };
      };

      channels-config = {
        allowUnfree = true;
        allowBroken = true;
        permittedInsecurePackages = [
          "electron-27.3.11"
        ];
	allowUnsupportedSystem = true;
        # allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
        #   "yEd"
        # ];
      };
    };

  /*
     outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
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
            home-manager.extraSpecialArgs = {inherit inputs;};
          }
        ];
      };
    };
    homeConfigurations = let
      system = "x86_64-linux";
    in {
      "ds13@salt" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system}; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {inherit inputs outputs;};
        modules = [
          # ./home-manager/default.nix
          (./home-manager/profiles + "/ds13@salt.nix")
          #./hosts/buddha.nix
          #./modules
          # ./configuration.nix
          # { nixpkgs.config.allowUnfree = true; }
          {
            nixpkgs.config = {
              permittedInsecurePackages = [
                "electron-27.3.11"
              ];
              allowUnfree = true;
              # allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
              #   "yEd"
              # ];
            };
          }
          # { nixpkgs.config.allowUnfree = true; { nixpkgs.config.allowUnsupportedSystem = true; }}
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
          (./home-manager/profiles + "/aspakalo@darwin.nix")
          # import ./test.nix
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
  */
}
