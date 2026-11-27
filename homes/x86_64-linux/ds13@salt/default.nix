{
  # Snowfall Lib provides a customized `lib` instance with access to your flake's library
  # as well as the libraries available from your flake's inputs.
  lib,
  # An instance of `pkgs` with your overlays and packages applied is also available.
  pkgs,
  # You also have access to your flake's inputs.
  inputs,
  # Additional metadata is provided by Snowfall Lib.
  namespace, # The namespace used for your flake, defaulting to "internal" if not set.
  home, # The home architecture for this host (eg. `x86_64-linux`).
  target, # The Snowfall Lib target for this home (eg. `x86_64-home`).
  format, # A normalized name for the home target (eg. `home`).
  virtual, # A boolean to determine whether this home is a virtual target using nixos-generators.
  host, # The host name for this home.
  # All other arguments come from the home home.
  config,
  ...
}:
let
  inherit (lib.${namespace}) disabled enabled;
in
{
  # REFACTOR: Implement auto-import via Snowfall-lib utils.
  imports = [
    ./syncthing/default.nix
    ./apps/network/sshfs/default.nix
    ./apps/network/ssh/default.nix
    ./apps/ecosystem/sops-opencode/default.nix
  ];

  home = {
    # This value determines the Home Manager release that your configuration is
    # compatible with. This helps avoid breakage when a new Home Manager release
    # introduces backwards incompatible changes.
    #
    # You should not change this value, even if you update Home Manager. If you do
    # want to update the value, then make sure to first check the Home Manager
    # release notes.
    stateVersion = "24.11";
    # Home Manager needs a bit of information about you and the paths it should
    # manage.
    username = "ds13";
    homeDirectory = "/home/ds13";
  };

  lib.${namespace} = {
    paths = rec {
      # config = ~/.config;
      kbd = ~/.bookmarks/kbn;
      kbn = ~/.bookmarks/kbn;
      projects = "~/Projects";

      dotfiles = "~/.local/dotfiles-";

      # TODO: Make like in @creamsoda.
      # shared-dotfiles = "${dotfiles}/shared-";
      shared-configs = "~/.bookmarks/shared-configs";
      shared-scripts = "~/.bookmarks/shared-scripts";

      # TODO: Append home- like in @creamsoda.
      # As far as I can tell, we would need at least change paths in Ansible
      # Keyszer templates.
      home-dotfiles = "${dotfiles}";
      home-configs = "${home-dotfiles}/_configs";
      home-scripts = "${home-dotfiles}/_scripts";
    };

    # TODO: Add as default value.
    deploymentOptions = rec {
      isDeployedFromDarwin = false;
      isNixGlNotWorking = isDeployedFromDarwin;
    };

    modules = {
      ai-assistance = {
        enable = true;
        codex = disabled;
        claude-code = disabled;
        opencode.ssh-session-plugin = enabled;
      };
      architecturing = {
        enable = true;

        # Issue: SSL certificate OpenSSL verify result: unable to get local issuer certificate
        # https://github.com/NixOS/nixpkgs/issues/409848
        staruml = disabled;
      };
      cli-utility = {
        enable = true;
      };
      development = {
        enable = true;

        # FIX: Has to be enabled explicitly.
        nix = enabled;
        # INFO: Already has installed via system means.
        gnumake = disabled;

        # Jira CLI, with per-space profiles configured below.
        jira-cli = enabled;
      };
      ecosystem = {
        enable = true;

        ansible = disabled; # Pipx issues as ansible has it's own python interpreter.

        # Nested SOPS domain: base SOPS is on via `ecosystem.enable`, and the
        # OpenCode child opts in explicitly. See
        # apps/ecosystem/sops-opencode/default.nix.
        sops.opencode = enabled;
      };
      general = {
        enable = true;

        neovim = {
          enabled = true; # TODO: Remove.
          dev = true;
          stage = true;
        };

        # App works fine but it doesn't connect to server. Seems like an issue
        # with ports, systemd or something like this. Hard to investigate as logs are
        # quite lacking.
        amnezia-client = disabled;

        # MacOs Specific things.
        karabiner-elements = disabled;
        skhd = disabled;
        yabai = disabled;

        obs-studio = disabled; # Takes 3.5Gb, currently don't use.
      };
      media = {
        enable = true;
        # FIX: Has to be enabled explicitly.
        audio = {
          enable = true;
          # NOTE: After switching run `systemctl --user restart pipewire-pulse`
          # so this module's `pipewire-pulse` drop-in is loaded.
          pipewire-pulse = enabled;
        };
      };
      gui-utility = {
        enable = true;

        # `inode/directory` / xdg-open -> ranger in wezterm. Does not touch
        # in-app (portal) file pickers; see `system-services.termfilechooser`.
        ranger-default-opener = enabled;
      };
      productivity = {
        enable = true;

        # FIX: Has to be enabled explicitly.
        taskwarrior = enabled;
      };
      misc = {
        qmk = enabled;
        cook-cli = enabled;
      };
      writing = {
        enable = true;
      };
      graphics = {
        enable = true;

        blender = disabled; # Takes 3.5Gb, currently don't use.
      };
      virtualisation = {
        enable = false;
      };
      system = {
        enable = true;
      };
      tools = {
        enabled = true;

        ranger = {
          enabled = true;
          dev = true;
          stage = true;
        };
      };
      network = {
        enable = true;

        # TODO: Repair.
        openvpn3 = disabled;
      };

      bookmarks = {
        enable = true;
        # Host-local project configs (RFC adding-nix-generated-files-into-container):
        # explicit opt-in; @salt uses the activation writer below.
        projects = enabled;
      };

      services = {
        enable = true;
      };
      system-services = {
        enable = true;

        awesomewm = {
          enabled = true;
          dev = true;
          stage = false;
          prod = false;
        };

        # In-app `org.freedesktop.portal.FileChooser` -> ranger inside wezterm.
        # NOTE: After switching, re-login X and run
        # `systemctl --user restart xdg-desktop-portal.service`.
        termfilechooser = enabled;
      };
    };

    services.zapret = {
      enable = true;
    };
  };

  ${namespace} = {
    development.docker = {
      enableAlias = true;
    };

    # Project configs are host-local on @salt: the generation root and manifest
    # are written by the activation generator, outside the synced tree. The
    # generated project paths stay untouched until the Phase 3 ignore boundary
    # is verified on the real host; flip `writeLinks` only after Phase 0/3
    # (see docs/rfc/adding-nix-generated-files-into-container/plan.md).
    bookmarks.projects = {
      writeMode = "activation";
      writeLinks = false;
    };

    # Jira CLI orgs/sites/spaces, mirroring Jira. An org owns the shared
    # connection fields; a site owns its URL and Cloud ID; a space owns the
    # Jira key and metadata. Profile ids mirror the path:
    # `<org>-<site>-<space>` -> `jira-<org>-<site>-<space>` executables.
    #
    # Personal Atlassian Cloud organization `ds13` has two sites: `antiskuf`
    # (JPD space AntiSkuf_discovery--roadmap-exploration, key `ASDRE`) and
    # `finding-work` (FindingJob_discovery--roadmap-exploring, key `FJDRE`).
    # Both share the login, token and proxy settings; each site supplies only
    # its URL, Cloud ID and spaces.
    #
    # The token is scoped. Atlassian requires scoped tokens to call
    # `https://api.atlassian.com/ex/jira/<cloudId>`, while `browse_server`
    # keeps `jira open` on the site URL.
    development.jira-cli = {
      # Exported as JIRA_CONFIG_FILE for a bare `jira`.
      default = "ds13-antiskuf-ASDRE";

      orgs.ds13 = {
        loginSecret = "jira_personal_login";
        installation = "Cloud";
        # Platform-scoped token used by jira-cli/MCP. The JPD-only token
        # remains under jira_personal_ds13_org_product_discovery_token.
        tokenSecret = "jira_personal_ds13_org_token";
        # Both personal sites are reachable only through the user's
        # proxychains config; work profiles stay direct.
        useProxychains = true;

        sites.antiskuf = {
          serverSecret = "jira_personal_antiskuf_site_server";
          cloudId = "0a71bd79-c53f-4219-9b44-889c0bf92253";
          # `jira-ds13-antiskuf` shortcut.
          defaultSpace = "ASDRE";
          spaces.ASDRE = {
            # JPD spaces are team-managed.
            spaceType = "next-gen";
          };
        };

        # FindingJob_discovery--roadmap-exploring lives on a different site in
        # the same ds13 organization. The scoped token is account-level, so it
        # is inherited; only the site URL, Cloud ID and space differ.
        sites.finding-work = {
          serverSecret = "jira_personal_finding_job_site_server";
          cloudId = "b51309ad-cdbd-4352-9f01-1949a65f2f22";
          # `jira-ds13-finding-work` shortcut.
          defaultSpace = "FJDRE";
          spaces.FJDRE = {
            # JPD spaces are team-managed.
          };
        };
      };
    };

    # Review-exchange role = "consumer" (PC): `/review` + the `review-agent` +
    # thin TS tool run here. The producer (@creamsoda) explicitly disables it.
    ai-assistance.opencode.customTools.review-exchange = true;
  };

  # Review-exchange machine-local state (§2). The schema copy must stay
  # byte-identical to the contract at `.agents/review-exchange-v1/`.
  home.file = {
    ".config/review-exchange/review-exchange.schema.json".source =
      ../../../.agents/review-exchange-v1/review-exchange.schema.json;
  };

  # Review-exchange consumer state root (D7): host-specific, read by the Python
  # via REVIEW_EXCHANGE_STATE_DIR (it `mkdir -p`s everything below).
  home.sessionVariables = {
    REVIEW_EXCHANGE_STATE_DIR = "/zsalt/var-/ds13@salt/state/review";
  };
}
