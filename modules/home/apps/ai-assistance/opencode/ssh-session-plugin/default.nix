{
  lib,
  config,
  pkgs,
  namespace,
  ...
}: let
  # Plugin built by Nix from the rev-pinned `opencode-ssh-session` flake input.
  plugin = pkgs.ds-omega.opencode-ssh-session;
in
  lib.${namespace}.mkIfEnabled
  {
    inherit config;
    category = "ai-assistance.opencode";
    name = "ssh-session-plugin";
  }
  {
    programs.opencode = {
      # Entries NOT starting with `file://` are npm-installed by OpenCode via
      # bun at startup (unreachable network here), so the pre-built plugin is
      # loaded directly from its store path instead.
      settings.plugin = [
        "file://${plugin}/dist/index.js"
      ];

      # Skill directory shipped by the plugin. Wired directly (not through the
      # repo's `skillPaths` mechanism): `skillPaths` derives the skill name via
      # `baseNameOf`, which propagates the store-path context into the
      # attribute name and fails evaluation. The home-manager module treats a
      # store-path string here as a skill directory.
      skills."ssh-remote-dev" = "${plugin}/share/skills/ssh-remote-dev";

      agents.ssh-remote-dev = ./agent/ssh-remote-dev.md;
    };
  }
