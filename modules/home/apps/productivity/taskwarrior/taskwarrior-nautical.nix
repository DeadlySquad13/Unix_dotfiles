{
  pkgs,
  lib,
  config,
  namespace,
  ...
}: let
  customUdas = pkgs.fetchurl {
    url = "https://github.com/catanadj/taskwarrior-nautical/raw/main/uda.conf";
    sha256 = "sha256-sjE2BmCwoGj0RkRypu+hz/7btUx++HUeF+p7MtgvV6Q=";
  };

  nauticalCore = pkgs.fetchzip {
    url = "https://github.com/catanadj/taskwarrior-nautical/archive/refs/heads/main.tar.gz";
    sha256 = "sha256-yIkI/PKJVAPpZiJwJpxZubFJ+PGHBj9AOwoU7Qu36RM=";
    stripRoot = true;
    # The tarball contains a single top-level directory "taskwarrior-nautical-main"
    # We only need the "nautical_core" subdirectory, so we strip the root and then
    # extract only that part. However, fetchzip doesn't support selective extraction,
    # so we'll instead symlink the whole extracted directory but then use a symlink
    # to the nautical_core subdirectory. Alternatively, we can just point to the
    # subdirectory after extraction.
    # Since we strip the root, the extracted content is exactly the contents of
    # taskwarrior-nautical-main, which includes nautical_core.
  };

  # The nautical_core is inside the extracted directory. We'll symlink it directly.
  nauticalCorePath = "${nauticalCore}/nautical_core";
in
  lib.${namespace}.mkIfEnabled
  {
    inherit config;
    category = "productivity.taskwarrior";
    name = "nautical";
  }
  {
    home = {
      file = {
        ".task/nautical_core".source = nauticalCorePath;

        # STYLE: Following taskwarrior convention of `<hook>[<identifier>]`.
        # https://taskwarrior.org/docs/hooks/
        ".task/hooks/on-add-nautical.py" = {
          source = "${pkgs.ds-omega.taskwarrior-nautical-hooks}/bin/on_add.py";
          executable = true;
        };
        ".task/hooks/on-modify-nautical.py" = {
          source = "${pkgs.ds-omega.taskwarrior-nautical-hooks}/bin/on_modify.py";
          executable = true;
        };
        ".task/hooks/on-exit-nautical.py" = {
          source = "${pkgs.ds-omega.taskwarrior-nautical-hooks}/bin/on_exit.py";
          executable = true;
        };

        ".config/task/nautical-custom-udas".text = builtins.readFile customUdas;
      };
    };

    programs.taskwarrior = {
      extraConfig =
        /*
        ini
        */
        ''
          include /home/ds13/.config/task/nautical-custom-udas
        '';
    };

    programs.bash.sessionVariables = {
      # Sets the root dir of the taskwarrior-nautical. It's `~/.task` by default
      # but in Nix environment it's resolved to `/nix`. We override it back via
      # variable.
      NAUTICAL_CORE_PATH = "~/.task"; # Tilde is resolved in a script.
    };
  }
