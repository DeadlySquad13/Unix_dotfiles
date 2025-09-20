{
  description = "NixOS configuration";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    };
    # TODO: Remove after release of Logseq
    # https://discuss.logseq.com/t/nixos-logseq-has-been-removed-due-to-lack-of-maintenance-and-blocking-the-electron-27-removal/31605/3
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixgl = {
      url = "github:nix-community/nixGL";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/nixos-wsl";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # For accessing `deploy-rs`'s utility Nix functions
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

      # The `specialArgs` parameter passes the
      # non-default nixpkgs instances to other nix modules
      # system.hosts.x86_64-linux.specialArgs = {
      #   # To use packages from nixpkgs-stable,
      #   # we configure some parameters for it first
      #   pkgs-stable = import inputs.nixpkgs-stable {
      #   };
      # };
      homes.users."ds13@salt".specialArgs = {
        # To use packages from nixpkgs-stable,
        # we configure some parameters for it first
        pkgs-stable = import inputs.nixpkgs-stable {
          config.permittedInsecurePackages = [
            "electron-27.3.11"
          ];
        };
      };

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
        # permittedInsecurePackages = [
        #   "electron-27.3.11"
        # ];
        allowUnsupportedSystem = false;
        # allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
        #   "yEd"
        # ];
      };

      systems.modules.nixos = with inputs; [
        nixos-wsl.nixosModules.wsl
        sops-nix.nixosModules.sops
        # Enable home-manager modules.
        home-manager.nixosModules.home-manager
      ];

      system.modules.darwin = with inputs; [
        # Enable home-manager modules.
        mac-app-util.homeManagerModules.default
      ];

      deploy.nodes.cake = {
        hostname = "cake";
        profiles.system = {
          sshUser = "ds13";
          # The owner of the profile. For system it's always root.
          user = "root";
          interactiveSudo = true;
          path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos inputs.self.nixosConfigurations.cake;
        };
      };

      # This is highly advised, and will prevent many possible mistakes.
      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks inputs.self.deploy) inputs.deploy-rs.lib;
    };
}
