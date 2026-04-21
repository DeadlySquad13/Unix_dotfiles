{
  pkgs,
  buildEnv,
}: let
  nauticalLibraries = with pkgs; [
    python3Packages.rich
  ];

  version = "v4.5.3";

  # Fetch the hook scripts from GitHub.
  onAddSrc = pkgs.fetchurl {
    url = "https://github.com/catanadj/taskwarrior-nautical/raw/${version}/on-add-nautical.py";
    sha256 = "sha256-Oc+mT4GY29tkA3ouojWShMemLFQDvlsE1lCUgUCa/zU=";
  };
  onModifySrc = pkgs.fetchurl {
    url = "https://github.com/catanadj/taskwarrior-nautical/raw/${version}/on-modify-nautical.py";
    sha256 = "sha256-aiZNbjC3Ky9e1JFM+EiaSE3Kr/CS82z8GS1+mVdWdDo=";
  };
  onExitSrc = pkgs.fetchurl {
    url = "https://github.com/catanadj/taskwarrior-nautical/raw/${version}/on-exit-nautical.py";
    sha256 = "sha256-1s+Wn8z8iKHt1NY8ABDu/o/9BtOaoHGeWp7uDGm4qQ8=";
  };

  # Add dependencies to the scripts. There will be two shebangs in each file:
  # 1. The one that nix has added (with it's own Python that has all the
  # dependencies)
  # 2. Generic python3 from env. 
  # Second will be ignored (it's considered a simple comment).
  # STYLE: We name python files in snake_case according to our conventions.
  onAdd = pkgs.writers.writePython3Bin "on_add.py" {
    libraries = nauticalLibraries;
    # INFO: Don't want to sync style with 3rd party scripts.
    doCheck = false;
  } (builtins.readFile onAddSrc);
  onModify = pkgs.writers.writePython3Bin "on_modify.py" {
    libraries = nauticalLibraries;
    doCheck = false;
  } (builtins.readFile onModifySrc);
  onExit = pkgs.writers.writePython3Bin "on_exit.py" {
    libraries = nauticalLibraries;
    doCheck = false;
  } (builtins.readFile onExitSrc);
in
  # Combine scripts to a single package.
  buildEnv {
    # INFO: Actually name of the file is taken into account when creating
    # a package name in SnowfallLib. It's just for sake of completeness.
    name = "taskwarrior-nautical-hooks";
    paths = [
      onAdd
      onModify
      onExit
    ];
  }
