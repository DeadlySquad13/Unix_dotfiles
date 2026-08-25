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
          {...}: {
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
          # Workaround: mcp-logseq 1.8.0 uses the MCP 1.x Server API, while
          # uvx otherwise resolves mcp 2.x, which removed Server.list_tools.
          # Remove `--with mcp<2` after a mcp-logseq release supports MCP 2.x.
          # Check its declared dependency with:
          # `uvx --from mcp-logseq python -c 'import importlib.metadata as m; print(m.metadata("mcp-logseq").get_all("Requires-Dist"))'`
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
        logseq = {
          image = "supercorp/supergateway:uvx";
          hostPort = 18103;
          endpointPath = "/mcp";
          clientEndpointPath = "/sse";
          stdioCommand = [
            "uvx"
            "--refresh"
            "--from"
            "mcp-logseq==1.8.0"
            "--with"
            "mcp<2"
            "mcp-logseq"
          ];
          environment.LOGSEQ_API_URL = "http://host.docker.internal:12315";
          extraHosts = ["host.docker.internal:host-gateway"];
          environmentFile = cfg.logseqEnvironmentFile;
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
      };
      description = "Declarative MCP server registry used by OpenCode and Compose generation.";
    };
  };

  options.ds-omega.ai-assistance.opencode.mcp.logseqEnvironmentFile = mkOption {
    type = types.nullOr types.str;
    default = null;
    description = "Runtime SOPS environment file for the Logseq MCP server.";
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
        ddg-search-mcpo = {
          enabled = false;
        };
        nixos-mcpo = {
          enabled = false;
        };
      };
      mcp = {
        enable = true;
        servers = (mapAttrs endpointFor mcpContainersCfg.servers) // mcpoServers;
      };
    };
  };
}
