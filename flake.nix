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
        allowUnsupportedSystem = true;
        permittedInsecurePackages = [
          "electron-27.3.11"
        ];
        # allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
        #   "yEd"
        # ];
      };
    };
}
