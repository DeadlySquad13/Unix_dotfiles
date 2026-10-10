{
  lib,
  config,
  namespace,
  ...
}: let
  inherit (lib.${namespace}) source;
  cfg = config.${namespace}.ai-assistance.opencode;
in
  lib.${namespace}.mkIfEnabled
  {
    inherit config;
    category = "ai-assistance";
    name = "opencode";
  }
  {
    # Default (e.g. a real machine): expose the SOPS-rendered template at the
    # canonical home path via `home.file`. Systems that set
    # `${namespace}.ai-assistance.opencode.authPath` (e.g. containers where the
    # persistent opencode share is symlinked to ~/.local/share/opencode) skip
    # this and let the external layer own auth.
    home-manager.users.${cfg.username} = {config, ...}: {
      home.file.".local/share/opencode/auth.json" =
        lib.mkIf (cfg.authPath == null)
        (lib.mkDefault (source {
          inherit config;
          # Sops template is not guaranteed to exist in nix store during build
          # so we're symlinking to its predetermined runtime location: it will
          # be available once the program is run.
          get-path = _p: "/run/secrets/rendered/opencode-auth.json";
          out-of-store = true;
        }));
    };
  }
  // {
    options.${namespace}.ai-assistance.opencode.authPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Absolute path where an external layer already exposes OpenCode's
        `auth.json`.

        - `null` (default): this module creates
          `~/.local/share/opencode/auth.json` as a `home.file` symlink to
          `/run/secrets/rendered/opencode-auth.json`.
        - set: this module does not manage auth; the selected external mechanism
          must provide a file or symlink at the given path. Docker systems set
          this to the persistent opencode share mount
          (`/usr/local/<spice>-/<system>/_share/opencode/auth.json`), which
          `services.runtime-home-bridge` symlinks to `~/.local/share/opencode`.
          This keeps `~/.local/share/opencode` a symlink rather than a real
          directory; a real directory would defeat the bind mount and lose the
          session database on every container start.
      '';
    };
  }
