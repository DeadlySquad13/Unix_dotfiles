{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.runtime-home-bridge;

  variantNames = lib.attrNames cfg.variants;
  catalogJson = pkgs.writeText "runtime-home-bridge-catalog.json" (builtins.toJSON {
    version = 1;
    inherit (cfg) homeDirectory namespaceRoot;
    variants = cfg.variants;
  });

  bridge = pkgs.writeShellApplication {
    name = "runtime-home-bridge";
    runtimeInputs = [ pkgs.coreutils pkgs.jq pkgs.util-linux ];
    text = ''
      set -euo pipefail

      catalog=${lib.escapeShellArg catalogJson}
      config_file=${lib.escapeShellArg cfg.runtimeConfig}
      home=${lib.escapeShellArg cfg.homeDirectory}
      namespace_root=${lib.escapeShellArg cfg.namespaceRoot}

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

      while IFS= read -r mapping; do
        source="$namespace_root/$(jq -er '.source' <<<"$mapping")"
        target="$home/$(jq -er '.target' <<<"$mapping")"
        create_link "$target" "$source"
      done < <(jq -c --arg variant "$variant" '.variants[$variant][]' "$catalog")
    '';
  };
in {
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

    variants = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf (lib.types.submodule {
        options = {
          source = lib.mkOption {
            type = lib.types.str;
            description = "Relative directory below namespaceRoot.";
          };
          target = lib.mkOption {
            type = lib.types.str;
            description = "Relative canonical path below homeDirectory.";
          };
        };
      }));
      default = { };
      description = "Build-time catalog of approved variant mappings.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.user != "" && cfg.homeDirectory != "" && cfg.namespaceRoot != "";
        message = "runtime-home-bridge requires user, homeDirectory, and namespaceRoot.";
      }
      {
        assertion = variantNames != [ ];
        message = "runtime-home-bridge requires at least one predefined variant.";
      }
      {
        assertion = lib.all (variant: lib.match "^[[:alnum:]_-]+$" variant != null) variantNames;
        message = "runtime-home-bridge variant names may contain only letters, digits, _, and -.";
      }
      {
        assertion = lib.all (mapping:
          lib.match "^[^/].*$" mapping.source != null
          && lib.match "^[^/].*$" mapping.target != null
          && lib.match "(^|/)\\.\\.(/|$)" mapping.source == null
          && lib.match "(^|/)\\.\\.(/|$)" mapping.target == null
        ) (lib.concatLists (lib.attrValues cfg.variants));
        message = "runtime-home-bridge mapping paths must be relative, single-line paths without '..' components.";
      }
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.homeDirectory}/.local 0755 ${cfg.user} users -"
      "d ${cfg.homeDirectory}/.local/state 0755 ${cfg.user} users -"
      "d ${cfg.homeDirectory}/.local/share 0755 ${cfg.user} users -"
      "d ${cfg.homeDirectory}/.bookmarks 0755 ${cfg.user} users -"
      "d ${cfg.homeDirectory}/Projects 0755 ${cfg.user} users -"
      "d ${cfg.homeDirectory}/Projects/--personal 0755 ${cfg.user} users -"
    ];

    systemd.services.runtime-home-bridge = {
      description = "Apply selected runtime home bridge variant";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-tmpfiles-setup.service" ];
      before = [ "systemd-user-sessions.service" "home-manager-${cfg.user}.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${bridge}/bin/runtime-home-bridge";
      };
    };

    systemd.services."home-manager-${cfg.user}" = {
      requires = [ "runtime-home-bridge.service" ];
      after = [ "runtime-home-bridge.service" ];
    };
  };
}
