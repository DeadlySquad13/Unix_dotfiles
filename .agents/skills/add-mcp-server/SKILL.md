---
name: add-mcp-server
description: This skill should be used when adding or adapting an MCP server in this Unix_dotfiles repository using the accepted generated-Compose design. It guides registry changes, generated host and development endpoints, rootless Docker lifecycle, validation, and transport troubleshooting; it does not implement Arion.
---

# Add an MCP server

Use this skill for a new MCP server in the accepted generated-Compose
architecture. Read [the accepted ADR](../../docs/adr/arion-mcp-architecture.md)
and [the repository guide](../../docs/guides/adding-mcp-server.md) before
editing. Treat the guide as the detailed operational reference rather than
duplicating it here.

## Preserve the architecture

- Treat `programs.opencode.mcpContainers.servers` as the declarative source of
  truth. Define a server once; derive both its Compose service and its host
  OpenCode endpoint from that registry. Do not add a separate hand-written
  Compose service or endpoint.
- Keep these concerns separate:
  - `modules/home/apps/ai-assistance/opencode/mcp.nix` defines the registry and
    its options and derives OpenCode endpoints.
  - `modules/home/apps/ai-assistance/opencode/mcp-compose.nix` is the Home
    Manager consumer. It filters `mcpContainers`, calls the pure root library,
    writes Compose YAML, and defines the systemd user lifecycle.
  - `lib/mcp-compose/default.nix` only generates YAML from `{ servers, pkgs }`.
    Keep Home Manager `config` and `cfg` out of this library.
- Use Snowfall lib auto-discovery for the root library. The current exposed
  function is `lib.ds-omega.generateMcpCompose`, implemented at
  `lib/mcp-compose/default.nix`. Confirm the namespace and function name in
  the current files before relying on them. Do not add manual `flake.nix`
  imports or OpenCode-module imports merely to expose the library.
- Implement the accepted generated-Compose design, not Arion. Do not add
  Arion dependencies, modules, or an Arion project as part of a normal server
  addition.

## Design the server record

Before writing Nix, record all of the following in the registry (and resolve
unknowns from the server's documentation or image):

1. Stable, safe logical name, Compose service name, and DNS identity.
2. Image, with an intentional tag or preferably an immutable digest.
3. Transport: native HTTP MCP (prefer Streamable HTTP or MCP-over-SSE), or
   stdio translated by Supergateway.
4. Native command, or the complete child command and Supergateway arguments.
5. Actual MCP endpoint path and transport semantics. Never substitute an
   OpenAPI `/docs` path.
6. Container listening port and a centrally allocated, non-conflicting host
   port. Publish host access on loopback only.
7. Non-secret environment, runtime environment-file path, secret references,
   and required credentials.
8. Read-only/read-write mounts, named volumes, ownership, backup, upgrade,
   cleanup, and persistence policy.
9. The shared `McpServers` network and any genuinely required additional
   network.
10. Health check/readiness probe and expected response; a listening TCP port
    alone is insufficient.

Keep secret values out of Nix expressions and generated store paths. Pass
secrets through runtime environment files or the repository's established
secret mechanism, and verify that generated YAML contains references rather
than secret contents.

## Select and validate transport

- Prefer native HTTP MCP whenever the server provides it. Configure its real
  HTTP command, container port, and MCP path without a wrapper.
- For stdio-only servers, run the child and Supergateway in one controlled
  service (normally the same image/container). Describe the child command and
  wrapper arguments reproducibly, and expose Supergateway's MCP-compatible SSE
  or Streamable HTTP endpoint.
- Never use `mcpo` and never use an OpenAPI `/docs` URL. Validate a real MCP
  handshake, not merely HTTP 200 or a documentation page.

## Derive both endpoint forms

Generate, do not hand-code, both network views:

- Host OpenCode: `http://127.0.0.1:<host-port><client-endpoint-path>`.
- A development container on `McpServers`:
  `http://<service-DNS-name>:<container-port><endpoint-path>`.

Use the actual client path for SSE versus Streamable HTTP. Do not use
`localhost` from a development container: it refers to that container.
Likewise, do not make host OpenCode depend on a container-only DNS name.

Declare `McpServers` in the generated MCP Compose project, which owns and
creates it. A development Compose project must use:

```yaml
networks:
  McpServers:
    external: true
    name: McpServers
```

Attach development services through Compose. Start the owning MCP project
first; normally do not run `docker network connect` or manually create the
network. Avoid `docker compose down` when dependent development projects are
running because the owner may remove the shared network.

## Implementation workflow

1. Read the ADR and guide, then inspect current `mcp.nix`, `mcp-compose.nix`,
   `lib/mcp-compose/default.nix`, Snowfall configuration, and Makefile targets.
2. Choose the transport and prove the image's command, endpoint path, port,
   readiness behavior, and persistence requirements.
3. Add one complete server record to
   `programs.opencode.mcpContainers.servers` in `mcp.nix`. Extend an option
   only when the server requires a reusable capability; keep deployment data
   out of the pure library.
4. Update the pure generator only when the registry schema or generated YAML
   needs a capability. Accept `{ servers, pkgs }` only and retain automatic
   Snowfall exposure through `lib.ds-omega.generateMcpCompose`.
5. Do not duplicate the server in OpenCode settings or a Compose file. Ensure
   `mcp-compose.nix` remains the sole Home Manager consumer and lifecycle
   owner.
6. Apply Home Manager, then use the repository lifecycle targets:

   ```sh
   make mcp-bootstrap
   make mcp-start
   make mcp-status
   make mcp-logs
   # Use as needed:
   make mcp-stop
   make mcp-restart
   ```

   Docker normally does not need restarting. Reconciliation through Compose
   recreates changed services; restart Docker only for daemon-level changes or
   an unhealthy rootless Docker service/socket.
7. Validate generated output, both endpoint forms, readiness, handshake, and
   persistence before declaring the change complete.

## Rootless Docker

Run Docker and Compose as the user owning the rootless daemon. Confirm the
effective UID, Docker context, `DOCKER_HOST` (normally the user's rootless
socket), and runtime-directory/socket availability agree between the shell,
systemd user service, and any SDK. Do not assume rootful `docker.service`, a
`docker` group, system privileges, or Docker-in-Docker. YAML generation needs
no socket; an SDK needs socket access only when it actually applies Compose.

## Validation

Use the actual generated path and project name when commands differ:

```sh
docker compose -f ./generated/mcp-compose.yml config
```

Then perform an MCP handshake from the host through the loopback URL and from
a development service through service DNS and the container port. Confirm the
service is ready, not merely `Up`; recreate a persistent service and verify
state remains in its declared volume. Check `opencode mcp list` and confirm
the new server reports success.

## Troubleshoot HTTP 405

Treat `405 Method Not Allowed` as a likely transport or path mismatch. Check,
in order:

1. Confirm the client uses the declared SSE or Streamable HTTP transport.
2. Confirm the client path is the MCP path, not `/docs`, a health path, or the
   server's non-MCP root path.
3. Confirm native HTTP versus Supergateway mode and its wrapper path/options.
4. Confirm host clients use the published host port while container clients
   use service DNS and the container port.
5. Inspect Compose configuration and logs, then repeat a real MCP handshake.

Do not “fix” a 405 by switching to mcpo or OpenAPI discovery.

## Completion checklist

- [ ] Read the accepted ADR and generated-Compose guide.
- [ ] Add the server once to `mcpContainers.servers`.
- [ ] Record image, transport, commands, path, ports, environment/secrets,
      mounts, network, readiness, and persistence.
- [ ] Prefer native HTTP; use Supergateway only for stdio-only servers.
- [ ] Derive loopback host and development DNS endpoints correctly.
- [ ] Keep secrets in runtime env files, not the Nix store.
- [ ] Keep registry, Home Manager consumer, and pure generator concerns
      separated; preserve Snowfall auto-discovery.
- [ ] Use the shared Compose-owned `McpServers` network with `external: true`
      in development projects; avoid manual network attachment.
- [ ] Verify rootless Docker context and run the MCP Make targets after HM
      changes.
- [ ] Validate Compose, readiness, host/container handshakes, and persistence.
- [ ] Do not add Arion, mcpo, or OpenAPI `/docs` configuration.
