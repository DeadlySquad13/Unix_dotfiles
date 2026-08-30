{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.runtime-home-bridge;

  variantNames = lib.attrNames cfg.variants;
  catalogJson = pkgs.writeText "runtime-home-bridge-catalog.json" (
    builtins.toJSON {
      version = 1;
      inherit (cfg) homeDirectory namespaceRoot zNamespaceRoot;
      variants = cfg.variants;
    }
  );

  # Standard home directories Home Manager manages during activation. The NixOS
  # image may pre-create some of them as root, so the bridge must make them
  # exist and be owned by the bridge user before Home Manager runs.
  managedHomeDirs = [
    ".config"
    ".cache"
    ".local"
    ".local/state"
    ".local/share"
    # Opencode's OpenCode config dir may be created by image build steps as
    # root (it owns a baked node_modules symlink); Home Manager later needs to
    # write opencode.json here.
    ".config/opencode"
  ];

  bridge = pkgs.writeShellApplication {
    name = "runtime-home-bridge";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.util-linux
    ];
    text = ''
      set -euo pipefail

      catalog=${lib.escapeShellArg catalogJson}
      config_file=${lib.escapeShellArg cfg.runtimeConfig}
      home=${lib.escapeShellArg cfg.homeDirectory}
      namespace_root=${lib.escapeShellArg cfg.namespaceRoot}
      z_namespace_root=${lib.escapeShellArg cfg.zNamespaceRoot}

      fail() {
        printf 'runtime-home-bridge: %s\n' "$*" >&2
        exit 1
      }

      if [ ! -e "$config_file" ]; then
        ${
        if cfg.required
        then ''fail "required runtime config is missing: $config_file"''
        else "exit 0"
      }
      fi

      variant=$(jq -er '
        if type != "object" or (.version != 1) or
           ((keys - ["version", "variant"]) | length != 0) or
           (.variant | type != "string" or length == 0)
        then error("expected exactly version and variant")
        else .variant
        end
      ' "$config_file") || fail "invalid runtime config: $config_file"

      jq -e --arg variant "$variant" '.variants[$variant] != null' "$catalog" >/dev/null ||
        fail "unknown variant: $variant"

      # Do not accept a bind mount at the canonical home target: a container
      # cannot safely turn an active mountpoint into a symlink.
      is_mountpoint() {
        findmnt -n --mountpoint "$1" >/dev/null 2>&1
      }

      create_link() {
        local target="$1"
        local source="$2"
        local parent temporary

        [ -d "$source" ] || fail "source for $target is not a directory: $source"
        case "$source" in "$namespace_root"/*) ;; *) fail "catalog source escapes namespace: $source" ;; esac
        case "$target" in "$home"/*) ;; *) fail "catalog target escapes home: $target" ;; esac

        if is_mountpoint "$target"; then
          fail "canonical target is a mountpoint; migrate the bind mount to $namespace_root: $target"
        fi

        parent=$(dirname "$target")
        mkdir -p "$parent"

        if [ -L "$target" ]; then
          [ "$(readlink "$target")" = "$source" ] && return 0
          rm "$target"
        elif [ -e "$target" ]; then
          fail "refusing to replace existing non-symlink target: $target"
        fi

        temporary="$parent/.runtime-home-bridge.$RANDOM"
        ln -s "$source" "$temporary"
        mv -T "$temporary" "$target"
      }

      # Extra link step for a mapping that carries an optional `zSource`. When
      # present it forms a chain down to the primary nodes (zsalt) destination:
      #   home/<target>                 -> namespace_root/<source>
      #   namespace_root/<source>       -> z_namespace_root/<zSource>
      # Without `zSource` only `create_link` runs (home/<target> -> source).
      create_z_link() {
        local z_source="$1"
        local namespace_link="$2"
        local z_target="$z_namespace_root/$z_source"
        local parent temporary

        [ -d "$z_target" ] || fail "z source for $namespace_link is not a directory: $z_target"

        parent=$(dirname "$namespace_link")
        mkdir -p "$parent"

        if [ -L "$namespace_link" ]; then
          [ "$(readlink "$namespace_link")" = "$z_target" ] && return 0
          rm "$namespace_link"
        elif [ -e "$namespace_link" ]; then
          fail "refusing to replace existing non-symlink namespace target: $namespace_link"
        fi

        temporary="$parent/.runtime-home-bridge.$RANDOM"
        ln -s "$z_target" "$temporary"
        mv -T "$temporary" "$namespace_link"
      }

      while IFS= read -r mapping; do
        source="$namespace_root/$(jq -er '.source' <<<"$mapping")"
        target="$home/$(jq -er '.target' <<<"$mapping")"

        # Chain down to the nodes (zsalt) source first when declared, so that
        # `create_link` below can resolve `$source` (which may become a symlink
        # into the z namespace):
        #   namespace_root/<source>       -> z_namespace_root/<zSource>
        #   home/<target>                 -> namespace_root/<source>
        if jq -e 'has("zSource") and (.zSource != null) and (.zSource != "")' <<<"$mapping" >/dev/null; then
          z_source="$(jq -er '.zSource' <<<"$mapping")"
          create_z_link "$z_source" "$source"
        fi

        create_link "$target" "$source"
      done < <(jq -c --arg variant "$variant" '.variants[$variant][]' "$catalog")
    '';
  };
in
  lib.ds-omega.mkIfEnabled
  {
    inherit config;
    category = "services";
    name = "runtime-home-bridge";
  }
  {
    services.runtime-home-bridge.package = bridge;

    assertions = [
      {
        assertion = cfg.user != "" && cfg.homeDirectory != "" && cfg.namespaceRoot != "";
        message = "runtime-home-bridge requires user, homeDirectory, and namespaceRoot.";
        # assertion = cfg.user != "" && cfg.homeDirectory != "" && cfg.namespaceRoot != "" && cfg.zNamespaceRoot;
        # message = "runtime-home-bridge requires user, homeDirectory, namespaceRoot, and zNamespaceRoot.";
      }
      {
        assertion = variantNames != [];
        message = "runtime-home-bridge requires at least one predefined variant.";
      }
      {
        assertion = lib.all (variant: lib.match "^[[:alnum:]_-]+$" variant != null) variantNames;
        message = "runtime-home-bridge variant names may contain only letters, digits, @, _, and -.";
      }
      {
        assertion = lib.all (
          mapping:
            lib.match "^[^/].*$" mapping.source
            != null
            && lib.match "^[^/].*$" mapping.target != null
            && lib.match "(^|/)\\.\\.(/|$)" mapping.source == null
            && lib.match "(^|/)\\.\\.(/|$)" mapping.target == null
            && (mapping.zSource == null || (
              lib.match "^[^/].*$" mapping.zSource != null
              && lib.match "(^|/)\\.\\.(/|$)" mapping.zSource == null
            ))
        ) (lib.concatLists (lib.attrValues cfg.variants));
        message = "runtime-home-bridge mapping paths must be relative, single-line paths without '..' components.";
      }
    ];

    systemd.tmpfiles.rules = [
      # Standard home directories Home Manager manages during activation. The
      # NixOS image may pre-create some of them as root; `d` only creates
      # missing ones while `Z` corrects ownership of those that already exist.
      # Keep this list in sync with `managedHomeDirs` below.
      "Z ${cfg.homeDirectory}/.config 0755 ${cfg.user} users -"
      "Z ${cfg.homeDirectory}/.cache 0755 ${cfg.user} users -"
      "Z ${cfg.homeDirectory}/.local 0755 ${cfg.user} users -"
      "Z ${cfg.homeDirectory}/.local/state 0755 ${cfg.user} users -"
      "Z ${cfg.homeDirectory}/.local/share 0755 ${cfg.user} users -"
      "d ${cfg.homeDirectory}/.bookmarks 0755 ${cfg.user} users -"
    ];

    # Directories that must exist and be owned by the bridge user before Home
    # Manager activation. Tmpfiles `Z` handles the common boot path; these
    # ExecStartPre steps make it deterministic regardless of tmpfiles ordering.
    systemd.services.runtime-home-bridge = {
      description = "Apply selected runtime home bridge variant";
      wantedBy = ["multi-user.target"];
      after = ["systemd-tmpfiles-setup.service"];
      before = [
        "systemd-user-sessions.service"
        "home-manager-${cfg.user}.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # NixOS image construction can leave these directories root-owned.
        # Unlike tmpfiles' `d`, ownership must be corrected when they already
        # exist and must be guaranteed before `home-manager-${cfg.user}` runs.
        ExecStartPre = builtins.concatLists (
          map (dir: [
            "${pkgs.coreutils}/bin/mkdir -p ${cfg.homeDirectory}/${dir}"
            "${pkgs.coreutils}/bin/chown ${cfg.user}:users ${cfg.homeDirectory}/${dir}"
          ])
          managedHomeDirs
        );
        ExecStart = "${bridge}/bin/runtime-home-bridge";
      };
    };

    systemd.services."home-manager-${cfg.user}" = {
      requires = ["runtime-home-bridge.service"];
      after = ["runtime-home-bridge.service"];
    };
  }
  // {
    options.services.runtime-home-bridge = {
      enable = lib.mkEnableOption "variant-selected runtime home symlinks";

      user = lib.mkOption {
        type = lib.types.str;
        description = "User whose home directory receives the canonical links.";
      };

      homeDirectory = lib.mkOption {
        type = lib.types.str;
        description = "Absolute home directory containing canonical link targets.";
      };

      namespaceRoot = lib.mkOption {
        type = lib.types.str;
        description = "Absolute safe Docker mount namespace root.";
      };

      zNamespaceRoot = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Absolute nodes (zsalt) root for optional chained zSource links.";
      };

      runtimeConfig = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.namespaceRoot}/_runtime/home-bridge.json";
        defaultText = lib.literalExpression ''"''${config.services.runtime-home-bridge.namespaceRoot}/_runtime/home-bridge.json"'';
        description = "Read-only JSON selector containing { version = 1; variant = <name>; }.";
      };

      required = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Fail boot bridge setup instead of doing nothing when runtimeConfig is absent.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        description = "Generated runtime-home-bridge script package; exposed for focused checks.";
      };

      variants = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.listOf (
            lib.types.submodule {
              options = {
                zSource = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Relative directory below zNamespaceRoot (nodes level).";
                };
                source = lib.mkOption {
                  type = lib.types.str;
                  description = "Relative directory below namespaceRoot (current node level).";
                };
                # TODO: zSource (zsalt) -> source (/usr/local/dotfiles-)
                #   -> homeLevelLocation (~/.local/dotfiles- with optional system and home differentiation)
                #   -> target
                target = lib.mkOption {
                  type = lib.types.str;
                  description = "Relative canonical path below homeDirectory.";
                };
              };
            }
          )
        );
        default = {};
        description = "Build-time catalog of approved variant mappings.";
      };
    };
  }
