<!-- mtoc-start -->

* [Unix dotfiles](#unix-dotfiles)
  * [Initialization](#initialization)
    * [Cloning](#cloning)
    * [Installation](#installation)
  * [Repository Structure](#repository-structure)
    * [2. Snowfall Lib and other notable Flake Inputs](#2-snowfall-lib-and-other-notable-flake-inputs)
    * [3. Use `mkFlake` to Define Flake Outputs](#3-use-mkflake-to-define-flake-outputs)
    * [4. Deployment](#4-deployment)
    * [5. Flake structure](#5-flake-structure)
    * [6. Packages](#6-packages)
    * [7. Overlays](#7-overlays)
    * [8. Modules](#8-modules)
    * [9. Systems](#9-systems)
    * [10. Homes](#10-homes)
    * [11. Templates](#11-templates)
    * [12. Shells](#12-shells)
    * [13. Checks](#13-checks)
    * [14. Automatic Importing and Exporting](#14-automatic-importing-and-exporting)
    * [15. Accessing Inputs and Libs](#15-accessing-inputs-and-libs)
    * [16. Merging Custom Outputs](#16-merging-custom-outputs)
  * [Working with Secrets](#working-with-secrets)
    * [Runtime Secrets](#runtime-secrets)
    * [Build-time Secrets](#build-time-secrets)
  * [References](#references)

<!-- mtoc-end -->
# Unix dotfiles

## Initialization

### Cloning

Has submodules for some modules [Source][@/GitSubmodulesNix]|[Zotero][z@/GitSubmodulesNix]:

* neovim
* wsl2-config

Because of that certain git operations like `clone` require submodule flags. Or explicitly update
submodules on initial clone:

```bash
make init
```

### Installation

To install flake use: `nixos-rebuild switch --flake . --impure`.
For non-NixOs systems, you can do the same thing by substituting `nixos-rebuilt` with `home-manager`:
`home-manager switch --flake . --impure`.

You can specify flake explicitly if you need: `home-manager switch --flake .#<user>@<hostname> --impure`,
for example, `home-manager switch --flake .#ds13@salt --impure`.

This configuration requires some special settings in `nix.conf`. While they're
ensured to be set there automatically, for the first time you may need activate
special flags manually, specifying them inline in the command:

```nix
home-manager switch --flake . --impure --extra-experimental-features 'nix-command flakes'
```

## Repository Structure

Mostly inherits Snowfall lib. It is a powerful library that simplifies managing
your Nix flake by providing an opinionated file structure and automating the
generation of flake outputs. This guide will walk you through setting up
Snowfall Lib in a flake-enabled Nix repository, focusing on defining flake
outputs like homes, systems, overlays, packages, modules, templates, and
shells. [Source][@/262588213843476/Snowfalllibguidecondensedmd]|[Zotero][z@/262588213843476/Snowfalllibguidecondensedmd]

### 2. Snowfall Lib and other notable Flake Inputs

In `flake.nix` there's `snowfall-lib` included in the `inputs` section.

Additionally a lot of our personal repositories are used as inputs. Some of
them are defined as git repositories, some, which require common change, are
imported as git submodules inside this monorepository.

The main idea of this convolution is to be as abstracted from a deployment tool
in our configs as much possible, while having benefits from using it. For some
of our projects Ansible playbooks are still developed. But at the same time
it's a shame not to use powerful Nix language to enrich or change system in
a coherent way.

```nix
{
  inputs = {
    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # INFO: Requires nix version >= 2.27
    self.submodules = true;

    neovim-config-prod = {
      url = "path:modules/home/apps/general/neovim/prod/NeoVim_config";
      flake = false;
    };

    neovim-config-stage = {
      url = "path:modules/home/apps/general/neovim/stage/NeoVim_config";
      flake = false;
    };

    wsl2-config = {
      url = "path:modules/home/apps/cli-utility/Wsl2_dotfiles";
      flake = false;
    };
  };
}
```

### 3. Use `mkFlake` to Define Flake Outputs

Option `inputs.snowfall-lib.mkFlake` is used to generate flake outputs automatically.
Some additional options for a whole flake are passed in `snowfall` field. Most
importantly, a name of the namespace is defined. It's used extensively in next
sections as it holds automatically imported modules (in a wide,
programming sense).

```nix
{
  outputs = inputs:
    inputs.snowfall-lib.mkFlake {
      inherit inputs;  # Pass your inputs to Snowfall Lib
      src = ./.;       # The root of your flake (can be customized)

      # ... homes configuration. ...

      snowfall = {
        namespace = "ds-omega";

        meta = {
          name = "ds-omega-flake";

          title = "Unix dotfiles flake";
        };
      };

      # ... modules, channels configuration. ...

      systems.modules = {
        # ... systems configuration. ...
      }
    };
}
```

### 4. Deployment

Part of the output is a deployment using `deploy-rs` (defined as input).

```nix
{
  outputs = inputs:
    inputs.snowfall-lib.mkFlake {
      #  ... some utils for separating modules depending on deploy strategy. ...
      # Especially usefull when cross-compiling from one system to another.

      deploy = {
            # ... deploy-rs config. ...
        };
      };

      outputs-builder = _channel: {
          # ... deploy automatic checks. ...
          # Prevent common misconfigurations and simple mistakes before actually
          # applying config. 
          checks = let
            inherit (inputs.nixkpgs.lib) mkIf;
          in
          mkIf (deploySystemsMatch systemToDeploy) (
            builtins.mapAttrs (
              system: deployLib: deployLib.deployChecks inputs.self.deploy
            )
            inputs.deploy-rs.lib
          );
    };
}
```

You can also pass through external packages or dynamically create new ones
in addition to the ones that `lib` will create from your `packages/` directory
using `outupts-builder`. But we use [7. Overlays](<README#7. Overlays>) for that.

### 5. Flake structure

Snowfall Lib expects a specific directory structure under your `root` directory (default is `.` or `./nix` if configured):

* `packages/`   : Define Nix packages
* `overlays/`   : Define Nixpkgs overlays
* `modules/`    : Define NixOS, Darwin, or Home Manager modules
* `systems/`    : Define system configurations
* `homes/`      : Define Home Manager configurations
* `templates/`  : Define flake templates
* `shells/`     : Define development shells
* `checks/`     : Define flake checks
* `lib/`        : Define shared library functions

### 6. Packages

Create a package by adding a directory under `packages/`:

```bash
mkdir -p packages/my-package
```

Create `packages/my-package/default.nix`:

```nix
{ pkgs, lib, ... }:

pkgs.stdenv.mkDerivation {
  name = "my-package";
  src = ./src;
  buildInputs = [ pkgs.someDependency ];
  # Additional build parameters
}
```

### 7. Overlays

Add overlays under `overlays/`:

```bash
mkdir -p overlays/my-overlay
```

Create `overlays/my-overlay/default.nix`:

```nix
{ inputs, channels, lib, ... }:

final: prev: {
  # Example: Override a package
  my-overridden-package = prev.somePackage.overrideAttrs (old: {
    version = "1.2.3";
    src = inputs.someInput;
  });
}
```

### 8. Modules

Place modules in `modules/nixos/`, `modules/darwin/`, or `modules/home/` depending on the target:

```bash
mkdir -p modules/nixos/my-module
```

Create `modules/nixos/my-module/default.nix`:

```nix
{ config, pkgs, lib, ... }:

{
  options.myOption = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "An example option";
  };

  config = {
    # Module implementation
    assertions = lib.assertions.assert (config.myOption) "myOption must be true";
  };
}
```

### 9. Systems

Add system configurations under `systems/<system-arch>/system-name/`:

```bash
mkdir -p systems/x86_64-linux/my-system
```

Create `systems/x86_64-linux/my-system/default.nix`:

```nix
{ config, pkgs, lib, ... }:

{
  imports = [
    ./modules/nixos/my-module  # Import your modules
  ];

  system.stateVersion = "23.05";  # Adjust as needed
  networking.hostName = "my-system";
  # Additional system configuration
}
```

### 10. Homes

Add Home Manager configurations under `homes/<system-arch>/user@host/`:

```bash
mkdir -p homes/x86_64-linux/user@my-system
```

Create `homes/x86_64-linux/user@my-system/default.nix`:

```nix
{ config, pkgs, lib, ... }:

{
  home.username = "user";
  home.homeDirectory = "/home/user";

  programs.zsh.enable = true;
  # Additional Home Manager configuration
}
```

### 11. Templates

Templates are useful for sharing project structures. Add them under `templates/`:

> It's not yet explored field.

```bash
mkdir -p templates/my-template
```

Place your template files inside this directory.

### 12. Shells

Create development shells under `shells/`:

> It's not yet explored field.

```bash
mkdir -p shells/my-shell
```

Create `shells/my-shell/default.nix`:

```nix
{ pkgs, lib, ... }:

pkgs.mkShell {
  packages = [ pkgs.someTool ];
  # Additional shell setup
}
```

### 13. Checks

Apart from basic checks provided by `deploy-rs` it's beneficial to add checks (sometimes system-specific) under `checks/`:

```bash
mkdir -p checks/my-check
```

Create `checks/my-check/default.nix`:

```nix
{ pkgs, lib, ... }:

pkgs.runCommand "my-check" { } ''
  echo "Running checks..."
  # Implement your checks

  # Should have an output to register as a valid derivation.
  touch $out
''
```

### 14. Automatic Importing and Exporting

Snowfall Lib automatically:

* **Imports** all files in the structured directories.
* **Exports** them under appropriate flake outputs:
  * Packages: `packages`
  * Overlays: `overlays`
  * Modules: `nixosModules`, `darwinModules`, `homeModules`
  * Systems: `nixosConfigurations`, `darwinConfigurations`, etc.
  * Homes: `homeConfigurations`
  * Shells: `devShells`
  * Checks: `checks`
  * Templates: `templates`
  * Library functions: `lib`

### 15. Accessing Inputs and Libs

Within your Nix files, you have access to:

* `inputs`: Your flake's inputs, allowing you to use other flakes.
* `lib`: A merged library that includes your own functions and those from inputs. Just create a new module at `./lib/<moduleName>`
Example usage:

```nix
{ inputs, lib, ... }:

let
  myFunction = lib.ds-omega.myHelperFunction;
in
# Use myFunction in your derivation or module
```

> **Note:** functions in `lib/<name>/default.nix` are merged **flat** into the
> single `lib.<namespace>` attrset. The directory name is not a namespace: a
> function defined in `lib/runtime-home-bridge/default.nix` is reached as
> `lib.ds-omega.resolveRuntimePaths`, not
> `lib.ds-omega.runtime-home-bridge.resolveRuntimePaths`.

### 16. `.bookmarks` and Nix paths

`~/.bookmarks/<name>` is the repo's centralized, human-friendly namespace for
project files, knowledge bases and shared configs. It is a set of symlinks
produced by several sources:

* the Home Manager `bookmarks` modules (`modules/home/bookmarks/…`); and
* the runtime-home-bridge systemd oneshot
  (`modules/nixos/services/runtime-home-bridge`), which creates the links
  inside containers at boot (see [ADR 0001](docs/adr/0001-runtime-home-bridge.md)).

At the Nix level, `lib.${namespace}.paths` is the central point that connects
this filesystem namespace to every module. Modules derive high-level options
from it (for example `config.programs.opencode.aiAssistanceDir`) and read the
resolved locations through the `get-path` helper in `lib/paths/default.nix`.

### Symlinks made by Nix vs. runtime symlinks

The difference that matters is *how* a symlink is created:

* **`mkOutOfStoreSymlink` (Nix-made)** symlinks are fine. They point at a
  `/nix/store/…` derivation output the builder created with `ln -s "<real>"`.
  Nix only ever consumes the output *string*; the target is baked into the
  build script as text, so no symlink-traversing path is statted or copied.
  The `.bookmarks` link materializes only at activation, as a runtime output.
* **Runtime symlinks** — plain `ln -s` in scripts or the `runtime-home-bridge`
  oneshot — are fine only when their value is used as a **string**. They break
  only in a Nix **path context**: a consumer module stat/copies the path
  (`pathIsDirectory`, `builtins.path`), or the value is materialized into the
  store. Symptom:

  ```
  error: path '…/AiAssistance__' is a symlink
  ```

So `paths.<x>` may hold a `.bookmarks` string as long as it is resolved to a
real, build-available path before it reaches a path context. `resolveRuntimePaths`
does exactly this — and only for keys actually managed by the host's runtime
bridge (`lib/runtime-home-bridge`), so you can keep writing `.bookmarks` strings
in `paths` while satisfying Nix. Home-manager `mkOutOfStoreSymlink` bookmarks
pass through unchanged. See
[ADR 0002](docs/adr/0002-path-resolution.md).

Docker hosts such as `darkGreen-tangerineDream` must take the runtime bridge
into account: their `projects`, `shared-configs` and `shared-scripts` are
created by the bridge, so their `paths` must be resolved from the source that is
valid at build time (the build-host real path), not the container-runtime
`/ztangerineDream/…` target. Otherwise you get `… does not exist` during the
image build.

### 17. Merging Custom Outputs

If you need to add custom outputs not managed by Snowfall Lib:

```nix
{
  outputs = inputs:
    let
      flakeOutputs = inputs.snowfall-lib.mkFlake {
        inherit inputs;
        src = ./.;
      };
    in
    flakeOutputs // {
      myCustomOutput = "Custom Value";
    };
}
```

For more detailed information, refer to the [Snowfall Lib documentation](https://github.com/snowfallorg/lib).

## Working with Secrets

All secrets are stored in a [secrets](./secrets) directory in encrypted
format.

### Runtime Secrets

Use [sops-nix](https://github.com/Mic92/sops-nix?tab=readme-ov-file). Some
pitfalls are described in [CONTRIBUTING, "Secrets Management" section](<CONTRIBUTING#Secrets Management>)

### Build-time Secrets

For build-time secrets we use custom solution that decrypts necessary files
before deployment using sops-nix. Secrets are stored in
a [`buildTime-`](./secrets/buildTime-) namespace as a secrets subdirectory. For
each node there's a corresponding folder. All secrets from a node of a specified node will be
decrypted and stored in a parallel structure inside `./secrets/tmp/<node>` directory.

For instance:

```nix

# It's actually at secrets/MelisStoke/buildTime-/xray-config.json, just encrypted.
# After unencrypting with `make decrypt-build-time-secrets NODE=MelisStoke` it
# will be at specified path in a tmp subdirectory.
configFile = ~/.bookmarks/Unix_dotfiles/secrets/tmp/MelisStoke/xray-config.json;
```

For more detail see:

* `decrypt-build-time-secrets` at [Makefile](./Makefile).
* [secrets tasks collection](./tasks/secrets.py)

> [!warning] Secrets at evaluation time is not secure enough.
> Use only for secrets you don't care that much (by someone that has access to
> your file system, any user has access to store) but still don't want to show
> in a public repository [Source][@/ComparisonSecretManaging]|[Zotero][z@/ComparisonSecretManaging].

## References

[@/GitSubmodulesNix]: <https://nixos.asia/en/blog/git-submodule-input> 'Git Submodules as Nix Flake Inputs'
[z@/GitSubmodulesNix]: <zotero://select/items/@/GitSubmodulesNix> 'Select in Zotero: Git Submodules as Nix Flake Inputs'
[@/262588213843476/Snowfalllibguidecondensedmd]: <https://gist.github.com/bibijeebi/4ecf11cd8f214da6e738777485001e9b> 'Snowfall-Lib-Guide-Condensed.Md'
[z@/262588213843476/Snowfalllibguidecondensedmd]: <zotero://select/items/@/262588213843476/Snowfalllibguidecondensedmd> 'Select in Zotero: Snowfall-Lib-Guide-Condensed.Md'
[@/ComparisonSecretManaging]: <https://nixos.wiki/wiki/Comparison_of_secret_managing_schemes> 'Comparison of Secret Managing Schemes - NixOS Wiki'
[z@/ComparisonSecretManaging]: <zotero://select/items/@/ComparisonSecretManaging> 'Select in Zotero: Comparison of Secret Managing Schemes - NixOS Wiki'
