# Adding an MCP server

This guide describes the operational workflow for the accepted generated-Compose
design. It is not an Arion implementation guide. The current design generates
ordinary Docker Compose YAML from a declarative registry. Arion is only a
possible future RFC alternative; it is not required for adding a server now.

The governing decision is [ADR: Generated Compose MCP deployment and OpenCode
integration](../adr/arion-mcp-architecture.md).

## Design at a glance

The declarative MCP registry is the source of truth. A server is added once to
that registry, and generation derives both:

1. the MCP deployment's Docker Compose YAML; and
2. the Home Manager `programs.mcp.servers` entry used by host OpenCode.

Do not add a hand-written Compose service and a separate hand-written OpenCode
endpoint. Duplicating either side makes names, ports, paths, and transports
drift.

The two generated endpoint forms are deliberately different:

- Host OpenCode uses `127.0.0.1` and the host-published loopback port.
- Development containers use the MCP service DNS name and the container port
  on the shared `McpServers` network.

## Information required in the registry

Before implementation, record the following for each server. Keep secret
values out of the registry where possible; store references to the repository's
secret mechanism instead.

| Field | Purpose |
| --- | --- |
| Logical name | Stable registry and OpenCode key, Compose service name, and DNS identity. Use a safe, unique name. |
| Image | Container image and, preferably, an immutable or intentionally managed tag/digest. |
| Transport | Native HTTP MCP, or stdio behind Supergateway. Record whether the endpoint is SSE or Streamable HTTP. |
| Command / wrapper | The server command and arguments. For stdio, describe the Supergateway command, child command, and wrapper options. |
| Endpoint path | The actual MCP path, including any prefix (for example `/mcp` or the server's SSE path). This is not an OpenAPI documentation path. |
| Container port | Port on which the HTTP MCP endpoint listens inside the container. |
| Host-published port | Explicit, non-conflicting loopback port for host OpenCode. Do not publish it broadly unless there is a documented need. |
| Environment and secrets | Non-secret settings, secret references, required credentials, and the name/path expected by the container. |
| Mounts and volumes | Bind mounts, read-only policy, named volumes, and ownership requirements. |
| Network | The shared `McpServers` network, plus any additional network that is actually required. |
| Health/readiness | Health check or a reliable readiness probe, including the endpoint and expected response. A listening TCP port alone may not mean MCP is ready. |
| Persistence | Whether state must survive container recreation, what volume owns it, and backup/upgrade/cleanup policy. |

Allocate host ports centrally. The container port is an internal contract and
the host port is a host-user resource; they do not need to be equal.

## Choose the MCP transport

### Native HTTP MCP

Prefer a server that natively exposes MCP over Streamable HTTP or MCP-over-SSE.
Register its image, command, container port, and real MCP endpoint path. The
generated Compose service exposes that endpoint, and both host and development
clients use it through the endpoint form appropriate to their network.

### Stdio-only MCP with Supergateway

For a server that only speaks stdio, run the server and Supergateway in the
same container (or otherwise in one controlled service). Supergateway translates
the child's stdio protocol into an MCP-compatible SSE or Streamable HTTP
endpoint. The registry must describe both the child command and the wrapper
arguments so the generated Compose command is reproducible.

Do **not** use `mcpo` or an OpenAPI `/docs` URL. An OpenAPI documentation page
is not an MCP transport, and an mcpo endpoint is explicitly rejected by the
ADR. Validate an actual MCP handshake, not merely an HTTP 200 response.

## Expected implementation changes

Once the implementation exists, a normal server addition should touch the
registry source and regenerate outputs. It should not require unrelated
manual configuration.

### Source of truth

Change the Nix module or data file that owns the declarative MCP registry. The
registry may eventually be split into shared data and host-specific overlays,
but there must remain one authoritative server definition. Add the server's
identity, transport, command/wrapper, endpoint, runtime resources, secrets, and
lifecycle metadata there.

### Generated deployment artifact

Regenerate the ordinary Compose YAML consumed by the MCP Compose project. The
result should include the service, its `McpServers` attachment, ports, mounts,
environment references, command, health/readiness settings, and persistence
objects. Treat this YAML as generated output: edit the registry, not the output.

### Generated client configuration

The registry generator should also produce the Home Manager
`programs.mcp.servers` entry. Its URL must use the host loopback address and
published port, with the correct MCP endpoint path. If a server's client form
needs command/args rather than a URL, that must still be derived consistently
from the registry and the selected transport.

In this repository, the eventual implementation is expected to involve the
Home Manager OpenCode/MCP module area under
`modules/home/apps/ai-assistance/opencode/`, the registry/generator module,
and the generated Compose project or artifact location selected by that
implementation. Exact filenames are implementation details. Do not preserve a
second legacy `programs.mcp.servers` definition for the same server.

## Network and endpoint rules

The MCP Compose project owns and creates the shared network named
`McpServers`. A development Compose project declares that network as external:

```yaml
networks:
  McpServers:
    external: true
    name: McpServers
```

and attaches a service with `networks: [McpServers]`. Normally the user does
not create or attach networks manually. Start the MCP Compose project first;
Compose creates `McpServers` and attaches development services while creating
them. The development service then reaches, for example,
`http://my-server:8000/mcp` (or the declared container port). Host OpenCode
instead reaches, for example, `http://127.0.0.1:18001/mcp`.

The external-network declaration does not transfer ownership. The MCP Compose
project remains responsible for the network's lifecycle. A development project
cannot start while its external network is absent.

## Rootless Docker requirements

Run every Docker command against the intended rootless daemon. The shell,
Home Manager user service, and any SDK that applies the stack must agree on:

- the effective user and Docker context;
- `DOCKER_HOST` (normally the user's rootless Docker socket); and
- the runtime-directory/socket availability.

Generating YAML does not require Docker socket access. If an SDK is used to
apply the stack, it may access the host rootless socket, but it must not start
an inner daemon. Do not assume a rootful `docker.service`, membership in a
`docker` group, or system-level privileges. SDK socket access is needed only if
the SDK actually runs Compose/Docker operations.

## Lifecycle and update procedure

MCP-specific Make targets live in `Makefile.opencode-mcp`, included by the
root `Makefile`. After applying Home Manager, bootstrap or control the
rootless user service with:

```sh
make mcp-bootstrap
make mcp-status
make mcp-logs
```

Use `make mcp-start`, `make mcp-stop`, or `make mcp-restart` for manual
lifecycle control. These targets manage the user unit and do not restart the
Docker daemon.

Use the generated Compose project directory and the same user/context that owns
the rootless daemon. Names below are illustrative; use the project's actual
Compose file and project name.

```sh
# Render/evaluate the registry, then validate the generated file.
docker compose -f ./generated/mcp-compose.yml config

# Create or reconcile services, network, and declared volumes.
docker compose -f ./generated/mcp-compose.yml up -d

# Review status and service output.
docker compose -f ./generated/mcp-compose.yml ps
docker compose -f ./generated/mcp-compose.yml logs --tail=100 my-server
```

Normally Docker does **not** need to be restarted. `docker compose up -d`
reuses running containers when their configuration is unchanged. When the
image, command, environment, mounts, ports, or other service configuration
changes, Compose may pull an image (when requested/needed) and recreate the
affected container. It leaves unrelated services running. Restart Docker only
when the daemon itself or its daemon-level configuration changed, or when the
rootless user Docker service/socket is unhealthy. Restarting the daemon is not
the normal way to deploy an MCP registry change.

After an update, repeat the readiness check and MCP handshake. A useful
high-level sequence is:

```sh
docker network inspect McpServers
docker compose -f ./generated/mcp-compose.yml up -d --pull missing
docker compose -f ./generated/mcp-compose.yml ps

# Use the server's real MCP client or a project-provided handshake probe.
# An HTTP status check or /docs page is insufficient.
```

If the generated stack is intentionally removed, remember that:

```sh
docker compose -f ./generated/mcp-compose.yml down
```

removes the services and, because this project owns it, may remove the shared
`McpServers` network. Do not run `down` casually while development Compose
projects still depend on that network. Named volumes are not removed unless
the appropriate volume-removal option is supplied, but verify the project's
cleanup policy before using it.

## Safe validation

Validate in this order:

1. Evaluate the registry and run `docker compose config` to catch malformed
   YAML, interpolation errors, duplicate ports, and invalid service fields.
2. Inspect `docker network inspect McpServers`; confirm the MCP service and any
   development test service are attached.
3. Check `docker compose ps` and service logs. Confirm health/readiness rather
   than assuming `Up` means usable.
4. From the host, perform an MCP handshake through the published loopback URL.
5. From a development container on `McpServers`, perform the same handshake
   through service DNS and the container port.
6. For persistent servers, recreate the container and verify that expected
   state remains in the declared volume.

## Worked conceptual examples

These are shapes, not copy-and-paste registry syntax.

### Stdio-only server

```text
name: git-tools
image: registry.example/git-tools:1.4
transport: stdio -> Supergateway (Streamable HTTP)
child command: /app/git-tools --stdio
endpoint path: /mcp
container port: 8000
host port: 18001 (127.0.0.1 only)
environment: GIT_TOKEN_FILE -> secret reference
mounts: named volume git-tools-cache:/var/lib/git-tools (persistent)
network: McpServers
readiness: MCP endpoint accepts a handshake
```

The generated command starts Supergateway with the child command. Host
OpenCode gets `http://127.0.0.1:18001/mcp`; a development container gets
`http://git-tools:8000/mcp`.

### Native HTTP server

```text
name: calendar
image: registry.example/calendar-mcp:2.0
transport: native Streamable HTTP
command: /app/calendar-mcp --http 0.0.0.0:8000
endpoint path: /mcp
container port: 8000
host port: 18002 (127.0.0.1 only)
environment: CALENDAR_CREDENTIALS_FILE -> secret reference
mounts: none
network: McpServers
readiness: /health plus successful MCP handshake
persistence: none
```

No wrapper is needed. The two generated client URLs are
`http://127.0.0.1:18002/mcp` and `http://calendar:8000/mcp`, respectively.

## Checklist

- [ ] Read and follow the [accepted ADR](../adr/arion-mcp-architecture.md).
- [ ] Add the server once to the declarative registry.
- [ ] Record name, image, transport, command/wrapper, endpoint path, ports,
      environment/secrets, mounts, network, readiness, and persistence.
- [ ] Prefer native HTTP; use Supergateway for stdio-only servers.
- [ ] Reject mcpo and OpenAPI `/docs` endpoints.
- [ ] Generate Compose and Home Manager client configuration from the registry.
- [ ] Use loopback host ports and service DNS/container ports for development.
- [ ] Validate Compose config, network membership, logs/readiness, and a real
      MCP handshake from both host and development contexts.
- [ ] Confirm rootless user/context/`DOCKER_HOST` and SDK socket assumptions.
- [ ] Use `docker compose up -d` for reconciliation; restart Docker only for
      daemon-level changes or daemon failure.
- [ ] Do not manually create/attach `McpServers`, and do not run `down` without
      understanding its shared-network impact.
- [ ] After switching `opencode mcp list` shows new mcp with success status
