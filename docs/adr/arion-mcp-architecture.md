# ADR: Generated Compose MCP deployment and OpenCode integration

- Status: Accepted
- Date: 2026-08-23

## Context

MCP servers need a stable deployment boundary and OpenCode needs transport
endpoints. The repository also has a rootless Docker host, a NixOS SDK
container used for evaluation, existing YAML Compose development projects, and
Home Manager configuration for OpenCode. Treating those as one Docker runtime
or one network would create unclear ownership and make client configuration
drift from deployment.

The immediate requirement is a small, understandable implementation that can
generate ordinary Docker Compose YAML from Nix. Arion may be evaluated later,
but it is not the deployment decision recorded here.

## Decisions

### 1. Use one declarative MCP registry

The MCP registry is the source of truth. It derives both:

- Docker Compose YAML for the MCP deployment; and
- Home Manager `programs.mcp.servers` endpoint entries.

The registry distinguishes host endpoints from container endpoints. Host
OpenCode uses loopback published ports. Development containers use service DNS
and container ports on the shared `McpServers` network.

### 2. Generate ordinary Docker Compose YAML

Use Nix attribute sets as the input model and `pkgs.formats.yaml` (or an
equivalent YAML mapper) to produce a regular Compose file. The generated file
contains one service per MCP server, the shared `McpServers` network, explicit
ports, mounts, environment references, and transport-specific commands.

The generated file is consumed by the standard Docker Compose CLI. A
Home Manager user service may run `docker compose up` for the user's rootless
Docker daemon, but Compose remains the deployment/runtime interface rather
than being hidden behind a new orchestration layer.

### 3. Keep evaluation and the Docker runtime separate

The NixOS SDK container may evaluate the Nix module and generate the Compose
file. The host rootless Docker daemon owns containers, networks, images, and
volumes. If the SDK is also used to apply the stack, it must use the host
rootless Docker socket with the same effective UID/context and `DOCKER_HOST`; it
must not start or select an inner daemon. Generating the file itself does not
require Docker socket access.

### 4. Use MCP transports, not OpenAPI discovery

Do not configure mcpo or an OpenAPI `/docs` endpoint. OpenCode requires
MCP-over-SSE or Streamable HTTP. Prefer a server's native HTTP MCP transport.
For stdio-only servers, use Supergateway to expose an MCP-compatible SSE or
Streamable HTTP endpoint.

### 5. Make `McpServers` the shared network boundary

The generated MCP Compose project declares and owns the `McpServers` network. A
Compose development project may attach to the already-created network as an
external network:

```yaml
services:
  app:
    image: example/app
    networks: [McpServers]

networks:
  McpServers:
    external: true
    name: McpServers
```

This means no manual `docker network connect` is required. Compose can attach
the service during creation. The MCP stack must be started first, and network
ownership and removal remain the responsibility of the MCP Compose project.

### 6. Keep deployment lifecycle user-scoped

Home Manager owns OpenCode client configuration and may also create a
`systemd.user.service` that runs the generated Compose project. Such a unit
must target the user's rootless Docker socket or user Docker service. It must
not assume a rootful `docker.service`, a `docker` group, or system-level
privileges.

If a user service starts the MCP stack, development projects must be ordered
after it (or explicitly require a readiness check), because an external
network cannot be attached before it exists.

## Consequences

### Positive

- Deployment and OpenCode endpoints cannot silently diverge when both are
  generated from the registry.
- The host retains one Docker daemon and one ownership model.
- Host and container networking have explicit, appropriate addresses.
- Existing YAML development projects can migrate incrementally.
- Rootless operation avoids requiring rootful Docker service access.
- Native HTTP and Supergateway cover the two supported MCP server shapes.

### Negative and operational cost

- If the SDK is later used to apply the generated stack, it gains access to the
  host Docker API and becomes a sensitive control-plane environment.
- UID, socket, `DOCKER_HOST`, runtime-directory, and user-systemd behavior
  require explicit validation.
- External network lifecycle and startup ordering must be documented.
- A registry generator must handle two endpoint forms and transport-specific
  configuration.
- Generated YAML adds a build-time mapping layer and requires explicit
  lifecycle and readiness handling.

## Rejected alternatives

### mcpo or OpenAPI `/docs`

Rejected because an OpenAPI documentation page or mcpo endpoint is not the MCP
transport OpenCode consumes. Native HTTP MCP or Supergateway is the required
interface.

### Independent hand-written OpenCode and deployment configuration

Rejected because it duplicates server names, ports, paths, and transport
choices, making drift likely.

### Docker-in-Docker or an SDK-local daemon

Rejected because it creates a second ownership domain, prevents development
containers from naturally sharing the host network, and complicates volumes,
images, permissions, and cleanup.

### Rootful system Docker service

Rejected because the target environment is rootless and user-scoped. It would
also make Home Manager units depend on system privileges and a Docker group.

### Mandatory immediate conversion of all Compose projects

Rejected because existing development YAML can join `McpServers` as an
external network. Incremental migration lowers risk.

### Arion

Not selected for the current implementation. Arion remains a candidate for a
future rewrite if the number of Compose projects, shared Nix modules, or
deployment lifecycle requirements justify its additional project model. See
the RFC for that proposal. The current generated Compose representation keeps
the runtime standard and makes migration or manual inspection easy.

## Validation criteria

Implementation is ready for broader adoption when:

1. An SDK invocation proves it reaches the host rootless daemon and creates no
   nested daemon.
2. Generated Compose creates the MCP services and `McpServers`, and removes
   only objects it owns according to the documented policy.
3. Host OpenCode completes an MCP handshake through a loopback published port.
4. A development Compose service reaches the same MCP server by service DNS on
   `McpServers` without manual network attachment.
5. A user-scoped startup path starts the MCP stack before development services
   and reports a useful failure when the external network is missing.
