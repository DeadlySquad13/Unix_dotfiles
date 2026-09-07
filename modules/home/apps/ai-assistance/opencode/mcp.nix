{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    mapAttrs
    mkIf
    mkOption
    types
    ;

  # # Mcpo.
  mcpoBaseUrl = "http://localhost:8001";
  mcpoUrl = serverName: mcpoBaseUrl + "/" + serverName;

  # The legacy `mcpo` (Model Context Protocol Orchestrator) gateway stays
  # registered for NON-opencode consumers of the shared MCP stack: everything
  # `logseq-mcpo` here is registered but DISABLED in OPENCODE ONLY (see
  # `settings.mcp."logseq-mcpo".enabled = false` below), so other agents/tools
  # over mcpo can still reach the graph-wide `logseq` endpoint.
  mcpoServers = {
    filesystem-mcpo = {
      url = mcpoUrl "filesystem";
    };
    memory-mcpo = {
      url = mcpoUrl "memory";
    };
    time-mcpo = {
      url = mcpoUrl "time";
    };
    fetch-mcpo = {
      url = mcpoUrl "fetch";
    };
    logseq-mcpo = {
      url = mcpoUrl "logseq";
    };
    ddg-search-mcpo = {
      url = mcpoUrl "ddg-search";
    };
    nixos-mcpo = {
      url = mcpoUrl "nixos";
    };
  };

  # # Container approach.
  cfg = config.ds-omega.ai-assistance.opencode.mcp;
  mcpContainersCfg = config.programs.opencode.mcpContainers;
  containerPort = 8000;
  endpointFor = name: server: {
    type = "remote";
    url =
      if mcpContainersCfg.accessMode == "docker-network"
      then "http://mcp-${name}:${toString containerPort}${server.endpointPath}"
      else "http://127.0.0.1:${toString server.hostPort}${server.clientEndpointPath}";
  };

  # --------------------------------------------------------------
  # Per-agent Logseq instances (namespace ACL profiles).
  #
  # One lightweight MCP gateway container per agent profile. Every instance is
  # a client of the SAME Logseq app (LOGSEQ_API_URL / SOPS token) — the host
  # ports are gateway ports, not Logseq instances. The per-process env is the
  # hard namespace ACL: LOGSEQ_WRITE_INCLUDES (write allow-list) and
  # LOGSEQ_INCLUDE_NAMESPACES (read allow-list; effective read = include ∪
  # write, "read extends write"). OpenCode's per-agent `tools` globs then
  # expose only each instance to its agent; OpenCode's own permissions model
  # is tool-name-pattern based and cannot express a namespace ACL, so the
  # process env is the enforcement point.
  #
  # There is deliberately NO generic `logseq` server: logseq access exists
  # only through explicit per-agent profiles (see
  # docs/guides/logseq-agent-namespaces.md).
  # --------------------------------------------------------------

  # Centrally allocated, non-conflicting host ports (registry uses 18101-18107).
  logseqPorts = {
    kbn = 18103;
    build = 18108;
    plan = 18109;
    docs-writer = 18110;
    nix-build = 18111;
    nix-plan = 18112;
    orchestrator = 18113;
    # Dedicated narrow instances for the <parent>-kbn summarizer subagents:
    # each writes ONLY the parent's own <parent-own>/_journals tree and reads
    # the parent's own (derived in logseq-profiles.nix, no config round-trip).
    summ-build = 18114;
    summ-plan = 18115;
    summ-docs-writer = 18116;
    summ-nix-build = 18117;
    summ-nix-plan = 18118;
  };

  allAgentOwns = lib.mapAttrs (_: profile: profile.own) cfg.logseqAgentProfiles;

  # Reserved complement marker: in a profile's writeSets / readSets it means
  # "everything NOT matched by LOGSEQ_EXCLUDE_NAMESPACES" — i.e. personal =
  # the complement of the agent-defined namespaces (no enumeration). See
  # docs/guides/logseq-agent-namespaces.md.
  personalMarker = "personal";

  # Concatenate the namespace bundles a profile references by name; the
  # `personal` marker is passed through literally rather than looked up.
  resolveSets = names:
    lib.concatLists (
      map (s:
        if s == personalMarker
        then [personalMarker]
        else cfg.logseqNamespaceSets.${s} or [])
        names
    );

  profileWriteIncludes = name: profile:
    [profile.own]
    ++ cfg.logseqSharedNamespaces
    ++ resolveSets profile.writeSets;

  # A summarizer profile is named `summ-<parent>`; it is READ-only on its
  # parent's own tree (so it can summarize results but never write there).
  # The parent's own is derived from the parent profile — no set bundle needed.
  summerParent = name: builtins.replaceStrings ["summ-"] [""] name;

  profileReadIncludes = name: profile:
    resolveSets profile.readSets
    ++ lib.optionals (lib.hasPrefix "summ-" name) [
      cfg.logseqAgentProfiles.${summerParent name}.own
    ]
    ++ lib.optionals profile.readAllAgentOwns (
      lib.attrValues (lib.filterAttrs (other: _: other != name) allAgentOwns)
    );

  # Does the profile carry the `personal` complement marker (read or write)?
  usesPersonal = profile:
    lib.any (s: s == personalMarker) (profile.writeSets ++ profile.readSets);

  # Set-bundle names the profile explicitly references (marker excluded).
  referencedSets = profile:
    lib.filter (s: s != personalMarker) (profile.writeSets ++ profile.readSets);

  # Namespaces the profile must NOT see even under the `personal` marker:
  # every OTHER profile's own tree plus the RESOLVED namespaces of every set
  # bundle this profile does not reference. Only derived when the profile
  # uses the marker — strict allow-lists already isolate the profile, and a
  # deny-list would otherwise block write access to its own referenced sets.
  profileExcludes = name: profile:
    if ! usesPersonal profile
    then []
    else
      lib.attrValues (lib.filterAttrs (other: _: other != name) allAgentOwns)
      ++ lib.concatLists (
        map (setName: resolveSets [setName]) (
          lib.filter (
            setName: ! lib.elem setName (referencedSets profile)
          ) (lib.attrNames cfg.logseqNamespaceSets)
        )
      );

  mkLogseqServer = name: profile: let
    write = profileWriteIncludes name profile;
    read = profileReadIncludes name profile;
    exclude = profileExcludes name profile;
    # When a Nix-pinned source (`logseqSrc`) is provided, mount it read-only
    # and install with `uvx --from <dir>` — the supercorp/supergateway:uvx
    # image ships uv/python but NOT git, so a `git+https://…@rev` spec fails
    # at container start. Without it we keep the git-URL spec (backward compat).
    hasLocalSrc = cfg.logseqSrc != null;
    stdioCommand =
      if hasLocalSrc
      then [
        "uvx"
        "--refresh"
        "--from"
        "/app/mcp-logseq"
        "mcp-logseq"
      ]
      else [
        "uvx"
        "--refresh"
        "--from"
        "git+https://github.com/dsOmega-StratoFrame/Mcp__Logseq.git@aa5550e64d8486ee8329ee9320fc82452e4eb0c2"
        "mcp-logseq"
      ];
    volumes =
      (lib.optionals hasLocalSrc ["${cfg.logseqSrc}:/app/mcp-logseq:ro"])
      ++ (profile.volumes or []);
  in {
    image = "supercorp/supergateway:uvx";
    hostPort =
      logseqPorts.${name}
      or (throw "mcp-logseq: no host port allocated for agent profile '${name}'");
    endpointPath = "/mcp";
    clientEndpointPath = "/sse";
    inherit stdioCommand volumes;
    environment =
      {LOGSEQ_API_URL = "http://${cfg.logseqHost}:12315";}
      // lib.optionalAttrs (write != []) {LOGSEQ_WRITE_INCLUDES = lib.concatStringsSep "," write;}
      // lib.optionalAttrs (read != []) {LOGSEQ_INCLUDE_NAMESPACES = lib.concatStringsSep "," read;}
      // lib.optionalAttrs (exclude != []) {LOGSEQ_EXCLUDE_NAMESPACES = lib.concatStringsSep "," exclude;};
    # Same SOPS token file the old single logseq server used.
    environmentFile = cfg.logseqEnvironmentFile;
  };

  logseqAgentServers = lib.mapAttrs' (
    name: profile: lib.nameValuePair "logseq-${name}" (mkLogseqServer name profile)
  ) (cfg.logseqAgentProfiles // cfg.logseqSummarizerProfiles);
in {
  options.programs.opencode.mcpContainers = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Deploy OpenCode MCP servers through generated Docker Compose YAML.";
    };

    dockerHost = mkOption {
      type = types.str;
      default = "unix://%t/docker.sock";
      description = "Rootless Docker socket used by the MCP user service.";
    };

    # TODO: Add a namespace option once needed and set in system. Similarly to
    # logseqEnvironmentFile
    accessMode = mkOption {
      type = types.enum [
        "host"
        "docker-network"
      ];
      default = "host";
      description = "Whether OpenCode reaches MCP servers through host loopback ports or the shared Docker network.";
    };

    servers = mkOption {
      type = types.attrsOf (
        types.submodule (
          _: {
            options = {
              image = mkOption {type = types.str;};
              hostPort = mkOption {type = types.port;};
              endpointPath = mkOption {type = types.str;};
              clientEndpointPath = mkOption {
                type = types.str;
                default = "/mcp";
              };
              nativeHttp = mkOption {
                type = types.bool;
                default = false;
              };
              stdioCommand = mkOption {
                type = types.listOf types.str;
                default = [];
              };
              environment = mkOption {
                type = types.attrsOf types.str;
                default = {};
              };
              extraHosts = mkOption {
                type = types.listOf types.str;
                default = [];
              };
              environmentFile = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
              volumes = mkOption {
                type = types.listOf types.str;
                default = [];
                description = "Extra Docker volume mounts (`name:path:ro` strings appended to the Compose service).";
              };
            };
          }
        )
      );
      default = {
        time = {
          image = "supercorp/supergateway:uvx";
          hostPort = 18101;
          endpointPath = "/mcp";
          clientEndpointPath = "/sse";
          stdioCommand = [
            "uvx"
            "mcp-server-time"
            "--local-timezone=Europe/Moscow"
          ];
        };
        fetch = {
          image = "supercorp/supergateway:uvx";
          hostPort = 18102;
          endpointPath = "/mcp";
          clientEndpointPath = "/sse";
          stdioCommand = [
            "uvx"
            "mcp-server-fetch"
          ];
        };
        filesystem = {
          image = "supercorp/supergateway:uvx";
          hostPort = 18106;
          endpointPath = "/mcp";
          clientEndpointPath = "/sse";
          stdioCommand = [
            "npx"
            "-y"
            "@modelcontextprotocol/server-filesystem"
            "/kbn"
          ];
        };
        memory = {
          image = "supercorp/supergateway:latest";
          hostPort = 18107;
          endpointPath = "/mcp";
          clientEndpointPath = "/sse";
          stdioCommand = [
            "npx"
            "-y"
            "@modelcontextprotocol/server-memory"
          ];
        };
        ddg-search = {
          image = "supercorp/supergateway:uvx";
          hostPort = 18104;
          endpointPath = "/mcp";
          clientEndpointPath = "/sse";
          stdioCommand = [
            "uvx"
            "duckduckgo-mcp-server"
          ];
        };
        nixos = {
          image = "ghcr.io/utensils/mcp-nixos:latest";
          hostPort = 18105;
          endpointPath = "/mcp";
          nativeHttp = true;
          environment = {
            MCP_NIXOS_HOST = "0.0.0.0";
            MCP_NIXOS_PORT = toString containerPort;
            MCP_NIXOS_TRANSPORT = "http";
          };
        };
      }
      // logseqAgentServers;
      description = "Declarative MCP server registry used by OpenCode and Compose generation.";
    };
  };

  options.ds-omega.ai-assistance.opencode.mcp = {
    logseqEnvironmentFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Runtime SOPS environment file for the Logseq MCP server.";
    };

    # Nix-pinned mcp-logseq source. When non-null the logseq containers mount
    # it read-only at /app/mcp-logseq and install with `uvx --from` (the
    # supercorp/supergateway:uvx image has uv/python but NO git, so a
    # `git+https://…@rev` spec fails at container start). See flake input
    # `mcp-logseq`.
    logseqSrc = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Nix store path of the mcp-logseq fork source at the pinned revision,
        mounted into each logseq container and installed via `uvx --from
        /app/mcp-logseq` (no git needed in the container image). Provided by
        `logseq-profiles.nix` from the `mcp-logseq` flake input.
      '';
    };

    logseqHost = mkOption {
      type = types.str;
      default = "localhost";
      description = ''
        Hostname or IP address where Logseq's HTTP API is reachable from inside
        the MCP container.  In rootless Docker the special name
        `host.docker.internal` resolves to the docker0 bridge which may be down,
        so the default is `localhost`.  Set this to the machine's LAN hostname
        (e.g. `salt`) so Docker's embedded DNS resolves it to the current LAN IP.
      '';
    };

    logseqSharedNamespaces = mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        Namespaces appended to EVERY agent profile's LOGSEQ_WRITE_INCLUDES
        (the global, human-curated shared trees). Each profile's write list is
        `own ++ logseqSharedNamespaces ++ sets(writeSets)`.

        The global default is provided by `logseq-profiles.nix` (as mkDefault);
        hosts only override when they need different values.
      '';
    };

    logseqNamespaceSets = mkOption {
      type = types.attrsOf (types.listOf types.str);
      default = {};
      description = ''
        Named namespace bundles referenced by a profile's `writeSets` /
        `readSets` (e.g. a `buildPair` tree shared by build+nix-build, a
        `planPair` tree shared by plan/nix-plan/kbn). Do NOT enumerate
        personal namespaces here — "personal" is derived as the complement
        of the agent-defined namespaces (see `readSets` / `writeSets`).

        The global default is provided by `logseq-profiles.nix` (as mkDefault).
      '';
    };

    logseqAgentProfiles = mkOption {
      type = types.attrsOf (
        types.submodule (
          {name, ...}: {
            options = {
              own = mkOption {
                type = types.str;
                description = "The agent's dedicated top-level namespace (base of its write include list).";
              };
              writeSets = mkOption {
                type = types.listOf types.str;
                default = [];
                description = "logseqNamespaceSets members appended to LOGSEQ_WRITE_INCLUDES. The reserved entry `personal` means every namespace NOT excluded from this profile (complement; excludes are derived automatically).";
              };
              readSets = mkOption {
                type = types.listOf types.str;
                default = [];
                description = "logseqNamespaceSets appended to LOGSEQ_INCLUDE_NAMESPACES (read-only extras; effective read = write ∪ read). The reserved entry `personal` grants read access to every namespace not excluded from this profile.";
              };
              readAllAgentOwns = mkOption {
                type = types.bool;
                default = false;
                description = "Also read every OTHER profile's own namespace (orchestrator role).";
              };
              volumes = mkOption {
                type = types.listOf types.str;
                default = [];
                description = "Extra Docker volumes added to this profile's logseq container (`name:path:ro` strings).";
              };
            };
          }
        )
      );
      default = {};
      description = ''
        Per-agent namespace ACL profiles. Each profile derives one mcp-logseq
        gateway container (`logseq-<name>`) whose env is the hard namespace
        ACL: LOGSEQ_WRITE_INCLUDES = own ++ shared ++ sets(writeSets);
        LOGSEQ_INCLUDE_NAMESPACES = sets(readSets) (+ every other profile's
        own when readAllAgentOwns); LOGSEQ_EXCLUDE_NAMESPACES is derived for
        profiles using the `personal` marker (defines personal = everything
        not under an agent namespace). No profiles → no logseq servers at all
        (logseq access is entirely profile-driven). OpenCode per-agent `tools`
        globs wire each agent to its instance.

        The global default is provided by `logseq-profiles.nix` (as mkDefault);
        hosts only override when they need different values.
      '';
    };

    logseqSummarizerProfiles = mkOption {
      type = types.attrsOf (
        types.submodule (
          {name, ...}: {
            options = {
              own = mkOption {
                type = types.str;
                description = "The kbn `<parent>/**` tree the summarizer may WRITE.";
              };
              writeSets = mkOption {
                type = types.listOf types.str;
                default = [];
              };
              readSets = mkOption {
                type = types.listOf types.str;
                default = [];
                description = "Bundles granting READ of the parent's own tree (to summarize results).";
              };
              readAllAgentOwns = mkOption {
                type = types.bool;
                default = false;
              };
              volumes = mkOption {
                type = types.listOf types.str;
                default = [];
              };
            };
          }
        )
      );
      default = {};
      description = ''
        Dedicated, NARROW instances for the `<parent>-kbn` summarizer subagents:
        each produces one `logseq-summ-<parent>` server whose WRITE list is the
        kbn `<parent>/**` tree (plus the global shared tree) and whose
        READ list is the parent's own tree only. They must never grant access
        to the broad `logseq-kbn*` instance (which may reach personal/shared).
        Provided by `logseq-profiles.nix` (as mkDefault).
      '';
    };
  };

  # QUESTION: Levae as mcp.nix in opencode and move rest to a seperate generic module mcp?
  config = mkIf (config.programs.opencode.enable && mcpContainersCfg.enable) {
    programs = {
      opencode.enableMcpIntegration = true;
      opencode.settings = {
        mcp = {
          filesystem-mcpo = {
            enabled = false;
          };
          memory-mcpo = {
            enabled = false;
          };
          time-mcpo = {
            enabled = false;
          };
          fetch-mcpo = {
            enabled = false;
          };
          # Disabled in OPENCODE ONLY: the mcpo `logseq` gateway stays
          # available for non-opencode consumers of the shared MCP stack.
          logseq-mcpo = {
            enabled = false;
          };
          ddg-search-mcpo = {
            enabled = false;
          };
          nixos-mcpo = {
            enabled = false;
          };
        };
        # Globs are required as we actually disable tools (that are part of
        # mcps)
        # Reference: https://github.com/anomalyco/opencode/pull/6306
        tools = {
          "filesystem*" = false;
          "memory*" = false;
          "time*" = false;
          "fetch*" = false;
          "logseq*" = false;
          "ddg-search*" = false;
          "nixos*" = false;
        };
        agent = let
          # Per-agent logseq tool grant: every agent is wired to ITS OWN
          # instance ONLY. Tool grants never inherit another agent's
          # logseq glob (each instance carries its own namespace ACL, so
          # cross-instance grants would leak other agents' trees).
          logseqGrant = name: {tools = {"logseq-${name}*" = true;};};
          # Non-logseq tool banks.
          baseTools = {
            time = {"time*" = true;};
            memory = {"memory*" = true;};
            fetch = {"fetch*" = true;};
            ddg = {"ddg-search*" = true;};
            filesystem = {"filesystem*" = true;};
            nixos = {"nixos*" = true;};
          };
          # rec-inheritance of the NON-logseq banks showing the logical agent
          # permission relationship (build → plan → docs-writer → kbn →
          # orchestrator; nix-build/nix-plan branch off build/plan). Only the
          # bank subsets flow through this chain — `logseqGrant` and
          # `permission.task` are applied per-agent at the leaf, never inherited.
          agentBanks = rec {
            build = baseTools.time // baseTools.memory;
            plan = build // baseTools.fetch // baseTools.ddg;
            docs-writer = plan // baseTools.filesystem;
            kbn = docs-writer;
            nix-build = build // baseTools.nixos;
            nix-plan = plan // baseTools.nixos;
            orchestrator = docs-writer;
          };
          # A `<parent>-kbn` counterpart: a hidden summarizer subagent that reads the
          # parent's own tree and writes a summary into the parent's own
          # `_journals` tree. It uses a DEDICATED narrow instance
          # `logseq-summ-<parent>` (ACL: write <parent-own>/_journals, read the
          # parent's own tree) — never the broad `logseq-kbn*` instance (which
          # may reach personal/shared) nor the parent's own instance. Persona
          # (mode/hidden/description) and tool grants live together in
          # `settings.agent` (opencode.json `agent` map), which the repo uses
          # for build/plan/nix-build/nix-plan the same way, and which lets the
          # mcp-logseq check assert them from the derived config.
          mkKbnCounterpart = parent:
            {
              mode = "subagent";
              hidden = true;
              description =
                "Reports ${parent} results into the knowledge-base journal (${cfg.logseqSummarizerProfiles."summ-${parent}".own}); reads ${parent}'s own tree, writes only via its dedicated journal instance or to shared instances it's included into";
              # Summarizers never run bash; they only read via logseq and write
              # summaries through the dedicated summary instance.
              permission.bash = "deny";
            }
            // {
              inherit (logseqGrant "summ-${parent}") tools;
            };
          # Subagent invocation is gated by permission.task (a `tools` glob
          # cannot). We do NOT deny `*` — that would forbid the agent's normal
          # task decomposition (general/explore/etc.). Instead deny only the
          # OTHER agents' `-kbn` counterparts (`*-kbn`) and allow exactly the
          # parent's own one; last matching rule wins, and OpenCode's default
          # for an unmatched subagent is "ask".
          delegateTo = parent: {
            permission.task = {
              "*-kbn" = "deny";
              "${parent}-kbn" = "allow";
            };
          };
        in {
          # Counterpart personas (mode/hidden/description) live in these
          # `settings.agent` blocks alongside their tool grants; opencode's
          # `agent` map supports pure-JSON subagents. The existing primary
          # personas (kbn/orchestrator/docs-writer) use the settings.agents
          # markdown route; both deep-merge with these grants.
          build = {
            tools = agentBanks.build // (logseqGrant "build").tools;
            # Delegate result-summarization to its counterpart. `permission.task`
            # gates subagent invocation (a `tools` glob cannot), see
            # docs/guides/logseq-agent-namespaces.md.
          } // delegateTo "build";
          plan = {
            tools = agentBanks.plan // (logseqGrant "plan").tools;
          } // delegateTo "plan";
          docs-writer = {
            tools = agentBanks.docs-writer // (logseqGrant "docs-writer").tools;
          } // delegateTo "docs-writer";
          kbn = {
            tools = agentBanks.kbn // (logseqGrant "kbn").tools;
          };

          # These agents are currently defined in Unix_dotfiles.
          nix-build = {
            tools = agentBanks.nix-build // (logseqGrant "nix-build").tools;
          } // delegateTo "nix-build";
          nix-plan = {
            tools = agentBanks.nix-plan // (logseqGrant "nix-plan").tools;
          } // delegateTo "nix-plan";
          orchestrator = {
            tools = agentBanks.orchestrator // (logseqGrant "orchestrator").tools;
          };

          # Hidden summarizer subagents (mode: subagent, hidden: true) invoked
          # programmatically by the parent via permission.task. Each gets
          # exactly {logseq-kbn*, logseq-<parent>*} + kbn's non-logseq banks.
          "build-kbn" = mkKbnCounterpart "build";
          "plan-kbn" = mkKbnCounterpart "plan";
          "docs-writer-kbn" = mkKbnCounterpart "docs-writer";
          "nix-build-kbn" = mkKbnCounterpart "nix-build";
          "nix-plan-kbn" = mkKbnCounterpart "nix-plan";
        };
      };
      mcp = {
        enable = true;
        servers = (mapAttrs endpointFor mcpContainersCfg.servers) // mcpoServers;
      };
    };
  };
}
