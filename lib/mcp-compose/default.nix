{lib}: {
  generateMcpCompose = {
    servers,
    pkgs,
  }: let
    inherit (lib) mapAttrs optionalAttrs;
    containerPort = 8000;
    toComposeService = name: server:
      {
        inherit (server) image;
        container_name = "mcp-${name}";
        ports = ["127.0.0.1:${toString server.hostPort}:${toString containerPort}"];
        networks.mcp.aliases = ["mcp-${name}"];
        restart = "unless-stopped";
      }
      // optionalAttrs (server.environment != {}) {inherit (server) environment;}
      // optionalAttrs (server.extraHosts != []) {extra_hosts = server.extraHosts;}
      // optionalAttrs (server.environmentFile != null) {env_file = [server.environmentFile];}
      // (
        if server.nativeHttp
        then {}
        else {
          command = [
            "--stdio"
            (lib.concatStringsSep " " (map lib.escapeShellArg server.stdioCommand))
            "--outputTransport"
            "sse"
            "--ssePath"
            "/sse"
            "--messagePath"
            "/message"
            "--port"
            (toString containerPort)
            "--healthEndpoint"
            "/healthz"
          ];
          healthcheck = {
            test = [
              "CMD"
              "node"
              "-e"
              "fetch('http://127.0.0.1:8000/healthz').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"
            ];
            interval = "10s";
            timeout = "3s";
            retries = 6;
            start_period = "10s";
          };
        }
      );
    compose = {
      name = "opencode-mcp";
      services = mapAttrs toComposeService servers;
      networks.mcp = {
        name = "McpServers";
        driver = "bridge";
      };
    };
  in
    (pkgs.formats.yaml {}).generate "opencode-mcp.yaml" compose;
}
