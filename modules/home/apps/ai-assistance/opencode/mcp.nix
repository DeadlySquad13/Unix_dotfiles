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
  cfg = config.programs.opencode.mcpContainers;
  containerPort = 8000;
  endpointFor = name: server: {
    type = "remote";
    url =
      if cfg.accessMode == "docker-network"
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

    accessMode = mkOption {
      type = types.enum [
        "host"
        "docker-network"
      ];
      default = "host";
      description = "Whether OpenCode reaches MCP servers through host loopback ports or the shared Docker network.";
    };

    logseqEnvironmentFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Runtime environment file containing LOGSEQ_API_TOKEN for the Logseq MCP server.";
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
        logseq = {
          image = "supercorp/supergateway:uvx";
          hostPort = 18103;
          endpointPath = "/mcp";
          clientEndpointPath = "/sse";
          stdioCommand = [
            "uvx"
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

  # QUESTION: Levae as mcp.nix in opencode and move rest to a seperate generic module mcp?
  config = mkIf (config.programs.opencode.enable && cfg.enable) {
    programs = {
      opencode.enableMcpIntegration = true;
      opencode.settings.mcp = {
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
      mcp = {
        enable = true;
        servers = mapAttrs endpointFor cfg.servers // mcpoServers;
      };
    };
  };
}
