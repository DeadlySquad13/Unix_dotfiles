{
  pkgs,
  lib,
  namespace,
  config,
  ...
}: let
  inherit (lib) mkOption types;

  cfg = config.${namespace}.development.jira-cli;

  # Used for generated executable names and file names, so keep it conservative.
  validId = name: builtins.match "[A-Za-z0-9_-]+" name != null;

  # Connection fields shared by orgs, sites and spaces. They are nullable so a
  # deeper node can tell "unset" (inherit) from an explicit value.
  connectionOptions = {
    server = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Plaintext Jira server URL. Prefer `serverSecret` to keep the URL out of
        the Nix store. Exactly one of `server`/`serverSecret` must be set after
        inheritance.
      '';
    };

    serverSecret = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Name of the sops-nix secret holding the server URL. Exactly one of
        `server`/`serverSecret` must be set after inheritance.
      '';
    };

    login = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Plaintext Jira login (email for Cloud, username for Local). Prefer
        `loginSecret`. Exactly one of `login`/`loginSecret` must be set after
        inheritance.
      '';
    };

    loginSecret = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Name of the sops-nix secret holding the Jira login. Exactly one of
        `login`/`loginSecret` must be set after inheritance.
      '';
    };

    installation = mkOption {
      type = types.nullOr (types.enum ["Cloud" "Local"]);
      default = null;
      description = ''
        Jira installation type. Resolves to `Cloud` when unset at every level.
      '';
    };

    authType = mkOption {
      type = types.nullOr (types.enum ["basic" "bearer" "mtls" "cf-access"]);
      default = null;
      description = ''
        Authentication type. `basic` for a Cloud API token; `bearer` for a
        Server/Data Center PAT. Resolves to `basic` when unset at every level.
      '';
    };

    cloudId = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Atlassian Cloud ID. When set, API calls use
        `https://api.atlassian.com/ex/jira/<cloudId>` while `browse_server`
        keeps the site URL. Required for scoped API tokens.
      '';
    };

    insecure = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Skip TLS certificate verification. Resolves to `false` when unset.";
    };

    useProxychains = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Run this profile through `proxychains4`. Resolves to `false` when
        unset; set it once per org/site when every space is proxied.
      '';
    };

    tokenSecret = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Name of the sops-nix secret holding `JIRA_API_TOKEN`. When null after
        inheritance, no token is managed and it must come from `.netrc`, the
        keyring, or the environment.
      '';
    };
  };

  # Metadata for one Jira space (or a legacy project). `name` is the attr name.
  metadataOptions = name: typeName: {
    key = mkOption {
      type = types.str;
      default = name;
      description = "Jira key. Defaults to the attr name.";
    };

    ${typeName} = mkOption {
      type = types.enum ["classic" "next-gen"];
      default = "classic";
      description = "Jira type (`project.type` in the jira-cli config).";
    };

    epicName = mkOption {
      type = types.str;
      default = "";
      description = "Epic custom field name (`epic.name`), e.g. `Epic Link`.";
    };

    epicLink = mkOption {
      type = types.str;
      default = "";
      description = "Epic custom field id (`epic.link`).";
    };

    board = mkOption {
      type = types.str;
      default = "";
      description = "Default board name (`board`); empty means none.";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Raw YAML appended to the generated config, typically the
        `issue.types`/`issue.fields.custom` metadata produced by `jira init`.
      '';
    };
  };

  # org -> site -> space, mirroring Jira. Each level inherits the connection
  # fields of its parent.
  spaceNode = types.submodule ({name, ...}: {
    options = connectionOptions // metadataOptions name "spaceType";
  });

  siteNode = types.submodule ({name, ...}: {
    options =
      connectionOptions
      // {
        defaultSpace = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Space under this site to expose as `jira-<org>-<site>`. When null,
            only the full `jira-<org>-<site>-<space>` executable is generated.
          '';
        };

        spaces = mkOption {
          type = types.attrsOf spaceNode;
          default = {};
          description = "Jira spaces on this site. The attr name is the space key unless `key` is set.";
        };
      };
  });

  orgNode = types.submodule ({name, ...}: {
    options =
      connectionOptions
      // {
        sites = mkOption {
          type = types.attrsOf siteNode;
          default = {};
          description = "Jira sites in this organization.";
        };
      };
  });

  # Legacy direct-space shape for Server/Data Center and older jira-cli. Kept
  # so existing `spaces.<space>.projects.<project>` configs keep working.
  legacyProjectNode = types.submodule ({name, ...}: {
    options = metadataOptions name "projectType";
  });

  legacySpaceNode = types.submodule ({name, ...}: {
    options =
      connectionOptions
      // {
        defaultProject = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Project under this space to expose as `jira-<space>`. When null,
            only the full `jira-<space>-<project>` executable is generated.
          '';
        };

        projects = mkOption {
          type = types.attrsOf legacyProjectNode;
          default = {};
          description = "Projects under this legacy space. The attr name is the project key unless `key` is set.";
        };
      };
  });

  # Fields inherited down the org -> site -> space chain. Metadata is not
  # inherited. The legacy chain additionally inherits `defaultProject`.
  connectionFields = [
    "server"
    "serverSecret"
    "login"
    "loginSecret"
    "installation"
    "authType"
    "cloudId"
    "insecure"
    "useProxychains"
    "tokenSecret"
  ];

  legacyFields = connectionFields ++ ["defaultProject"];

  # Drop nulls so an unset child does not override an inherited value.
  setFields = fields: attrs:
    lib.filterAttrs (name: value: builtins.elem name fields && value != null) attrs;

  # Merge one node over its inherited fields. If a child switches where a
  # credential comes from (plaintext <-> sops), drop the inherited counterpart
  # so the "exactly one source" assertions stay meaningful.
  mergeNode = fields: inherited: node: let
    own = setFields fields node;
    base = inherited // own;
    afterServer =
      if own ? server
      then removeAttrs base ["serverSecret"]
      else if own ? serverSecret
      then removeAttrs base ["server"]
      else base;
  in
    if own ? login
    then removeAttrs afterServer ["loginSecret"]
    else if own ? loginSecret
    then removeAttrs afterServer ["login"]
    else afterServer;

  # Apply global defaults after inheritance.
  finalize = merged: {
    server = merged.server or null;
    serverSecret = merged.serverSecret or null;
    login = merged.login or null;
    loginSecret = merged.loginSecret or null;
    cloudId = merged.cloudId or null;
    tokenSecret = merged.tokenSecret or null;
    defaultProject = merged.defaultProject or null;
    installation =
      if (merged.installation or null) != null
      then merged.installation
      else "Cloud";
    authType =
      if (merged.authType or null) != null
      then merged.authType
      else "basic";
    insecure =
      if (merged.insecure or null) != null
      then merged.insecure
      else false;
    useProxychains =
      if (merged.useProxychains or null) != null
      then merged.useProxychains
      else false;
  };

  # org -> site -> space profiles. Profile id mirrors the path.
  orgProfiles =
    lib.concatMap (orgName: let
      org = cfg.orgs.${orgName};
      orgMerged = mergeNode connectionFields {} org;
    in
      lib.concatMap (siteName: let
        site = org.sites.${siteName};
        siteMerged = mergeNode connectionFields orgMerged site;
      in
        lib.mapAttrsToList (spaceName: space: let
          spaceMerged = mergeNode connectionFields siteMerged space;
          final = finalize spaceMerged;
        in {
          kind = "org";
          id = "${orgName}-${siteName}-${spaceName}";
          inherit orgName siteName spaceName;
          space = final;
          meta = {
            key = space.key;
            projectType = space.spaceType;
            inherit (space) epicName epicLink board extraConfig;
          };
          templateName = "jira-${orgName}-${siteName}-${spaceName}.yml";
        }) site.spaces)
      (lib.attrNames org.sites))
    (lib.attrNames cfg.orgs);

  # Legacy space -> project profiles.
  legacyProfiles =
    lib.concatMap (spaceName: let
      space = cfg.spaces.${spaceName};
      final = finalize (mergeNode legacyFields {} space);
    in
      lib.mapAttrsToList (projectName: project: {
        kind = "legacy";
        id = "${spaceName}-${projectName}";
        inherit spaceName projectName;
        space = final;
        meta = {
          key = project.key;
          projectType = project.projectType;
          inherit (project) epicName epicLink board extraConfig;
        };
        templateName = "jira-${spaceName}-${projectName}.yml";
      }) space.projects)
    (lib.attrNames cfg.spaces);

  profileList = orgProfiles ++ legacyProfiles;
  profiles = lib.listToAttrs (map (profile: lib.nameValuePair profile.id profile) profileList);

  defaultProfile =
    if cfg.default == null
    then null
    else profiles.${cfg.default} or null;

  # Every secret referenced by any final profile.
  secretNames = lib.unique (lib.concatMap (profile:
    lib.optional (profile.space.serverSecret != null) profile.space.serverSecret
    ++ lib.optional (profile.space.loginSecret != null) profile.space.loginSecret
    ++ lib.optional (profile.space.tokenSecret != null) profile.space.tokenSecret)
  profileList);

  # If a secret name is set, emit a sops-nix template placeholder; otherwise
  # emit the literal as a JSON/YAML scalar.
  yamlSecretOr = secret: literal:
    if secret != null
    then "\"${config.sops.placeholder.${secret}}\""
    else builtins.toJSON literal;

  # jira-cli still spells the leaf `project:`. For both org spaces and legacy
  # projects, `meta.projectType` maps to `project.type`.
  renderConfig = profile: let
    header =
      if profile.kind == "org"
      then ''
        # Organization: ${profile.orgName}
        # Site: ${profile.siteName}
        # Space: ${profile.spaceName}
      ''
      else ''
        # Space: ${profile.spaceName}
        # Project: ${profile.projectName or ""}
      '';
  in ''
    # Generated by Home Manager from `${namespace}.development.jira-cli`.
    ${header}# Profile id: ${profile.id}
    #
    # Rendered by sops-nix at activation. `server`/`login` may be substituted
    # from SOPS secrets, so this file is read-only; keep non-secret metadata
    # in `extraConfig` instead of editing it in place.
    installation: ${builtins.toJSON profile.space.installation}
    server: ${
      if profile.space.cloudId != null
      then builtins.toJSON "https://api.atlassian.com/ex/jira/${profile.space.cloudId}"
      else yamlSecretOr profile.space.serverSecret profile.space.server
    }
    # jira-cli uses `browse_server` for `jira open`; a scoped API token
    # forces `server` onto the api.atlassian.com gateway, so keep the site
    # URL here for browser links.
    browse_server: ${yamlSecretOr profile.space.serverSecret profile.space.server}
    login: ${yamlSecretOr profile.space.loginSecret profile.space.login}
    auth_type: ${builtins.toJSON profile.space.authType}
    project:
      key: ${builtins.toJSON profile.meta.key}
      type: ${builtins.toJSON profile.meta.projectType}
    epic:
      name: ${builtins.toJSON profile.meta.epicName}
      link: ${builtins.toJSON profile.meta.epicLink}
    board: ${builtins.toJSON profile.meta.board}
    insecure: ${lib.boolToString profile.space.insecure}
  ''
  + lib.optionalString (profile.meta.extraConfig != "") ''
    # --- profile-specific metadata (extraConfig) ---
    ${profile.meta.extraConfig}
  '';

  # One PATH executable per profile. The sops-rendered config path is baked in;
  # the token is read from its 0400 file at runtime so no secret value lands in
  # the Nix store or in an exported registry.
  profileWrapper = profile:
    pkgs.writeShellApplication {
      name = "jira-${profile.id}";
      runtimeInputs =
        [cfg.package pkgs.coreutils]
        ++ lib.optional profile.space.useProxychains pkgs.proxychains;
      text = ''
        config_file=${lib.escapeShellArg config.sops.templates.${profile.templateName}.path}
        token_file=${
          lib.escapeShellArg (
            if profile.space.tokenSecret != null
            then config.sops.secrets.${profile.space.tokenSecret}.path
            else ""
          )
        }
        auth_type=${lib.escapeShellArg profile.space.authType}

        if [[ -n "$token_file" && -r "$token_file" ]]; then
          JIRA_API_TOKEN="$(cat "$token_file")"
          export JIRA_API_TOKEN
        fi
        JIRA_CONFIG_FILE="$config_file"
        JIRA_AUTH_TYPE="$auth_type"
        export JIRA_CONFIG_FILE JIRA_AUTH_TYPE

        exec ${lib.optionalString profile.space.useProxychains "proxychains4 "}jira "$@"
      '';
    };

  wrapperByName = lib.listToAttrs (map (profile:
    lib.nameValuePair "jira-${profile.id}" (profileWrapper profile))
  profileList);

  # `defaultSpace` on a site -> `jira-<org>-<site>` shortcut.
  orgShortcuts =
    lib.concatMap (orgName: let
      org = cfg.orgs.${orgName};
    in
      lib.concatMap (siteName: let
        site = org.sites.${siteName};
      in
        lib.optional (site.defaultSpace != null) {
          id = "${orgName}-${siteName}";
          targetId = "${orgName}-${siteName}-${site.defaultSpace}";
        }) (lib.attrNames org.sites))
    (lib.attrNames cfg.orgs);

  # `defaultProject` on a legacy space -> `jira-<space>` shortcut.
  legacyShortcuts =
    lib.concatMap (spaceName: let
      space = cfg.spaces.${spaceName};
    in
      lib.optional (space.defaultProject != null) {
        id = spaceName;
        targetId = "${spaceName}-${space.defaultProject}";
      }) (lib.attrNames cfg.spaces);

  shortcutList = orgShortcuts ++ legacyShortcuts;

  # Shortcut id -> wrapper. Targets a profile wrapper by its id.
  shortcutWrapperByName = lib.listToAttrs (map (shortcut:
    lib.nameValuePair "jira-${shortcut.id}" (pkgs.writeShellApplication {
      name = "jira-${shortcut.id}";
      text = ''
        exec ${wrapperByName."jira-${shortcut.targetId}"}/bin/jira-${shortcut.targetId} "$@"
      '';
    })) shortcutList);

  # Dynamic dispatcher for scripts. Accepts profile ids and shortcuts.
  profileDispatcher = pkgs.writeShellApplication {
    name = "jira-profile";
    runtimeInputs = [cfg.package];
    text = ''
      if (( $# < 1 )); then
        printf 'usage: jira-profile <profile-id|shortcut> [jira args...]\n' >&2
        exit 2
      fi
      profile="$1"
      shift
      case "$profile" in
        ${lib.concatStrings (map (profile: ''
          ${lib.escapeShellArg profile.id})
            exec ${wrapperByName."jira-${profile.id}"}/bin/jira-${profile.id} "$@"
            ;;
        '')
        profileList)}
        ${lib.concatStrings (map (shortcut: ''
          ${lib.escapeShellArg shortcut.id})
            exec ${shortcutWrapperByName."jira-${shortcut.id}"}/bin/jira-${shortcut.id} "$@"
            ;;
        '')
        shortcutList)}
        *)
          printf 'jira: unknown profile %s\n' "$profile" >&2
          printf 'available profiles: %s\n' ${lib.escapeShellArg (lib.concatStringsSep " " profileValues)} >&2
          exit 2
          ;;
      esac
    '';
  };

  profileIds = map (profile: profile.id) profileList;
  shortcutIds = map (shortcut: shortcut.id) shortcutList;
  profileValues = lib.unique (profileIds ++ shortcutIds);
  executableNames = map (value: "jira-${value}") profileValues;

  defaultConfigExport = lib.optionalString (defaultProfile != null) ''
    export JIRA_CONFIG_FILE=${lib.escapeShellArg config.sops.templates.${defaultProfile.templateName}.path}
  '';

  defaultTokenExport = lib.optionalString (defaultProfile != null && defaultProfile.space.tokenSecret != null) ''
    if [[ -r ${lib.escapeShellArg config.sops.secrets.${defaultProfile.space.tokenSecret}.path} ]]; then
      export JIRA_API_TOKEN="$(cat ${lib.escapeShellArg config.sops.secrets.${defaultProfile.space.tokenSecret}.path})"
    fi
  '';

  defaultAuthExport = lib.optionalString (defaultProfile != null) ''
    export JIRA_AUTH_TYPE=${lib.escapeShellArg defaultProfile.space.authType}
  '';
in
  lib.recursiveUpdate
  (lib.${namespace}.mkIfEnabled
    {
      inherit config;
      category = "development";
      name = "jira-cli";
    }
    {
      assertions = [
        {
          assertion = cfg.default == null || builtins.hasAttr cfg.default profiles;
          message = "development.jira-cli.default must name an existing profile id.";
        }
        {
          assertion = lib.all validId (profileIds ++ shortcutIds);
          message = "development.jira-cli org, site, space and project names may only contain A-Z, a-z, 0-9, `_` and `-`.";
        }
        {
          assertion = builtins.length profileIds == builtins.length (lib.unique profileIds);
          message = "development.jira-cli has colliding profile ids; space names must be unique within a site and legacy space names unique at top level.";
        }
        {
          assertion = let
            raw = profileIds ++ shortcutIds;
          in
            builtins.length raw == builtins.length (lib.unique raw);
          message = "development.jira-cli generated `jira-*` executable names collide; rename an org, site, space or project.";
        }
        {
          assertion = !(builtins.elem "profile" profileValues);
          message = "development.jira-cli: a profile named `profile` would collide with the jira-profile dispatcher.";
        }
        {
          assertion = lib.all (orgName: let
            org = cfg.orgs.${orgName};
          in
            lib.all (siteName: let
              site = org.sites.${siteName};
            in
              site.defaultSpace == null || builtins.hasAttr site.defaultSpace site.spaces)
            (lib.attrNames org.sites))
          (lib.attrNames cfg.orgs);
          message = "development.jira-cli.<org>.<site>.defaultSpace must name one of that site's spaces.";
        }
        {
          assertion = lib.all (spaceName: let
            space = cfg.spaces.${spaceName};
          in
            space.defaultProject == null || builtins.hasAttr space.defaultProject space.projects)
          (lib.attrNames cfg.spaces);
          message = "development.jira-cli.<space>.defaultProject must name one of that space's projects.";
        }
        {
          assertion = lib.all (profile:
            (profile.space.server != null) != (profile.space.serverSecret != null))
          profileList;
          message = "development.jira-cli: set exactly one of `server` or `serverSecret` per space (directly or inherited).";
        }
        {
          assertion = lib.all (profile:
            (profile.space.login != null) != (profile.space.loginSecret != null))
          profileList;
          message = "development.jira-cli: set exactly one of `login` or `loginSecret` per space (directly or inherited).";
        }
        {
          assertion = lib.all (profile:
            profile.space.cloudId == null
            || (profile.space.installation == "Cloud" && profile.space.authType == "basic"))
          profileList;
          message = "development.jira-cli.<space>.cloudId requires installation = \"Cloud\" and authType = \"basic\" (scoped API token gateway).";
        }
        {
          assertion = let
            bad = lib.concatMap (orgName: let
              org = cfg.orgs.${orgName};
            in
              lib.concatMap (siteName: let
                site = org.sites.${siteName};
              in
                lib.optional (site.spaces == {} && site.defaultSpace != null) "${orgName}/${siteName}")
              (lib.attrNames org.sites))
            (lib.attrNames cfg.orgs);
          in
            bad == [];
          message = "development.jira-cli: a site with `defaultSpace` must define at least one space.";
        }
      ];

      home.packages =
        [cfg.package]
        ++ lib.attrValues wrapperByName
        ++ lib.attrValues shortcutWrapperByName
        ++ [profileDispatcher];

      # Expose the default profile to every shell/agent, not only Bash. The
      # token itself still comes from the secret path in `bashrcExtra`.
      home.sessionVariables =
        lib.optionalAttrs (defaultProfile != null) {
          JIRA_CONFIG_FILE = config.sops.templates.${defaultProfile.templateName}.path;
          JIRA_AUTH_TYPE = defaultProfile.space.authType;
          JIRA_DEFAULT_PROFILE = cfg.default;
        }
        // lib.optionalAttrs (profileIds != []) {
          JIRA_PROFILES = lib.concatStringsSep " " profileValues;
          JIRA_PROFILE_EXECUTABLES = lib.concatStringsSep " " executableNames;
        };

      # Neither a secret value nor a literal `server`/`login` that was opted
      # into SOPS lands in the Nix store: the template only contains opaque
      # placeholders, and sops-nix substitutes them at activation.
      sops.secrets = lib.genAttrs secretNames (_: {
        mode = "0400";
      });

      sops.templates = lib.listToAttrs (map (profile:
        lib.nameValuePair profile.templateName {
          mode = "0600";
          content = renderConfig profile;
        })
      profileList);

      programs.bash.bashrcExtra = ''
        # jira-cli: per-profile config + token wiring.
        # Profiles are PATH executables generated from
        # `${namespace}.development.jira-cli`; this block only exports the
        # default profile and shell-completion metadata.

        ${defaultConfigExport}
        ${defaultTokenExport}
        ${defaultAuthExport}

        # Complete `--profile` from the Nix-generated registry (ids only; no
        # PATH scan, no secrets).
        _jira_search_complete() {
          local cur prev
          cur="''${COMP_WORDS[COMP_CWORD]}"
          prev="''${COMP_WORDS[COMP_CWORD-1]}"

          case "$prev" in
            --profile)
              COMPREPLY=( $(compgen -W "''${JIRA_PROFILES:-}" -- "$cur") )
              return 0
              ;;
          esac

          case "$cur" in
            --profile=*)
              local value="''${cur#--profile=}"
              COMPREPLY=( $(compgen -W "''${JIRA_PROFILES:-}" -- "$value") )
              COMPREPLY=( "''${COMPREPLY[@]/#/--profile=}" )
              return 0
              ;;
            -*)
              return 0
              ;;
          esac

          if (( COMP_CWORD == 1 )); then
            COMPREPLY=( $(compgen -W "search list view comments open edit copy profiles refresh" -- "$cur") )
            return 0
          fi

          return 1
        }
        complete -F _jira_search_complete jira-search jira.py 2>/dev/null || true
      '';
    })
  {
    options.${namespace}.development.jira-cli = {
      package = mkOption {
        type = types.package;
        default = pkgs.jira-cli-go;
        defaultText = lib.literalExpression "pkgs.jira-cli-go";
        description = "jira-cli package to install.";
      };

      default = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Profile id exported as `JIRA_CONFIG_FILE` for a bare `jira`
          invocation: `<org>-<site>-<space>` for `orgs`, `<space>-<project>`
          for legacy `spaces`. When null, every profile must be selected
          explicitly.
        '';
      };

      orgs = mkOption {
        type = types.attrsOf orgNode;
        default = {};
        description = ''
          Atlassian organizations. Each org contains `sites`, and each site
          contains `spaces`, mirroring Jira: `orgs.<org>.sites.<site>.spaces.<space>`.
          Connection fields set on an org are inherited by its sites and
          spaces; a deeper node overrides only what it sets. Profile ids are
          `<org>-<site>-<space>`.
        '';
      };

      spaces = mkOption {
        type = types.attrsOf legacySpaceNode;
        default = {};
        description = ''
          Legacy direct spaces for Server/Data Center and older jira-cli:
          `spaces.<space>.projects.<project>`. New Cloud configs should use
          `orgs` instead. Profile ids are `<space>-<project>`.
        '';
      };
    };
  }
