# RFC: Consider Arion for a future MCP container deployment

- Status: Deferred proposal
- Scope: MCP container stack and its development integrations
- Decision owner: maintainers of the Unix dotfiles deployment

## Summary

Consider adopting Arion as a future declarative deployment interface for MCP
containers. This RFC does not change the current implementation decision: the
initial MCP stack will use Nix-generated Docker Compose YAML and the standard
Compose CLI. Arion is a possible later rewrite if the number of stacks and
shared modules justifies its additional project model.

If adopted, the NixOS SDK container, `darkGreen-tangerineDream` (and the
related `x86_64-docker` system), would evaluate and apply Arion projects. The
SDK would not run a Docker daemon. It would use the host user's rootless Docker
daemon through the host Docker socket.

The host daemon owns the actual containers, networks, images, and volumes.
Arion projects would declare MCP services and the shared `McpServers` network.
Development Compose projects can initially remain YAML and join that network
as an external network. Home Manager configures OpenCode clients; it does not
deploy the containers.

## Proposed architecture

```text
                         evaluates/applies
  NixOS SDK container  ---------------------->  host rootless Docker daemon
  darkGreen-tangerineDream                         |
   (future Arion + Nix evaluation)                  +-- MCP containers
        |                                          +-- McpServers network
        |                                          +-- images and volumes
        +-- host rootless Docker socket

  Home Manager -------------------------------> OpenCode MCP endpoints
  (client configuration)       loopback ports / service DNS, as applicable

  Development Compose project -- external --> McpServers
```

### Ownership boundaries

| Concern | Owner |
| --- | --- |
| MCP service definitions, images, environment, volumes, and network declaration | Arion projects evaluated by the SDK container (if adopted) |
| Running containers, network objects, images, and volumes | Host rootless Docker daemon |
| OpenCode `programs.mcp.servers` entries and client-side environment | Home Manager |
| Development application services | Their existing Compose project, initially YAML |

The `McpServers` network is the integration boundary. The current generated
Compose project creates and owns it; a future Arion project could replace that
owner. A development Compose file refers to it with `external: true`; it must
not try to create a second network with the same name. Containers on the
network address MCP services by Compose service name and container port. Host
OpenCode instead uses loopback addresses for ports published by the MCP stack.

## Critical Docker-context requirement

The SDK container must control the *host* rootless daemon, not an accidental
inner Docker daemon. Before applying an Arion project, verify all of the
following inside the SDK container:

1. The Docker socket is mounted from the host and is the socket selected by
   the host user's rootless Docker context.
2. The effective UID and relevant group/socket permissions allow access to
   that socket. A numeric UID mismatch can look like an Arion or Docker
   failure while actually being a permissions failure.
3. `DOCKER_HOST` is explicitly set or deliberately inherited to the host
   rootless socket, for example `unix:///run/user/<uid>/docker.sock` (the
   actual host path is environment-specific).
4. Docker context selection, `XDG_RUNTIME_DIR`, and other client settings are
   consistent between the SDK invocation and the host user session.
5. No Docker-in-Docker daemon, privileged nested daemon, or alternate socket
   is started by the SDK image.

A smoke test must compare `docker context show`, `docker info`, and the socket
path from both contexts, then create a disposable container and confirm that
it appears in the host user's `docker ps`. The test must be safe to remove and
must not use rootful `docker.service` assumptions.

## Future Arion project shape

The first project should declare the MCP stack and the shared network in one
place. Each service should specify its image or build, environment, mounts,
health check, exposed/container port, and restart policy. Host publication is
only needed for host OpenCode; service-to-service access should use the
`McpServers` network and container ports.

Development Compose files can use this pattern while migration is staged:

```yaml
services:
  development-app:
    image: example/development-app
    networks: [McpServers]

networks:
  McpServers:
    external: true
    name: McpServers
```

The MCP stack must be started before a development project that references
the external network. Network removal and stack shutdown procedures must make
the MCP deployment project the owner of `McpServers` explicit.

## Registry and client configuration

Maintain one declarative MCP registry as the source of truth. It should
contain, at minimum, the logical server name, transport, container/service
address, container port, host-published port (when needed), and any secret or
environment references. From that registry derive:

- Compose YAML deployment definitions (currently); a future Arion
  representation could replace this; and
- Home Manager `programs.mcp.servers` endpoint configuration.

Use native HTTP MCP when a server provides it. For a stdio-only server, run
Supergateway as the HTTP MCP bridge and configure OpenCode for the bridge's
MCP-over-SSE or Streamable HTTP endpoint. Do not use mcpo or an OpenAPI
`/docs` URL: those are not the MCP transport OpenCode requires.

Host OpenCode should use published loopback ports (for example,
`http://127.0.0.1:<port>/...`). Development containers should use service DNS
names and container ports (for example, `http://mcp-server:<port>/...`) over
`McpServers`.

## Alternatives considered

### Generated Compose YAML with `pkgs.formats.yaml`

Nix can generate ordinary Compose YAML from a registry. This is a good
low-level fallback and can be useful for development projects, but it leaves
deployment lifecycle, validation, and Docker invocation conventions to custom
glue. Prefer it when compatibility with existing Compose tooling is the
primary requirement or when Arion cannot express a needed feature.

### compose2nix

compose2nix is useful for importing an existing Compose description into Nix.
It is less suitable as the long-term source of truth for a deliberately
Nix-native stack: generated output can be noisy and may not model the desired
deployment lifecycle or registry-to-client derivation cleanly.

### nix-managed-docker-compose

This can provide a NixOS-oriented service wrapper around Compose. It is worth
considering when a system module and user-systemd lifecycle are more valuable
than Arion's project model. It does not remove the need to define rootless
Docker ownership, external-network ordering, and SDK socket access.

### Standard Compose plus user systemd

A user-scoped systemd unit running `docker compose up` is straightforward and
is the current implementation path. It is preferred for a small stack or when
Compose-native behavior is essential. It requires careful readiness, restart,
secret, and cleanup handling, and does not inherently provide the same Nix
evaluation boundary as Arion.

Arion should be reconsidered when the deployment is already described in Nix,
the SDK container is the controlled evaluation point, and a single declarative
registry should produce multiple deployment projects and OpenCode
configuration. It is not required for the initial MCP implementation.

## Risks and prerequisites

### Prerequisites

- Arion is available in the selected Nix evaluation context.
- The SDK image contains the required Arion, Docker client, and shell tooling.
- The host has a running rootless Docker daemon and a stable user socket.
- SDK socket mounts, UID mapping, `DOCKER_HOST`, and runtime directory policy
  are documented and tested.
- MCP images, credentials, persistent volume paths, health checks, and port
  assignments are known.
- The `McpServers` name and ownership policy are fixed before development
  projects begin attaching to it.
- OpenCode endpoint paths and supported transport (SSE or Streamable HTTP)
  are verified for every server.

### Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| SDK connects to an inner or rootful daemon | Pin and test the socket, UID, `DOCKER_HOST`, and `docker info`; do not start a nested daemon. |
| Socket access exposes the host Docker API | Treat the SDK container as host-Docker privileged; minimize image contents and access, and document the trust boundary. |
  | External network is absent or removed | Start the MCP stack first; validate network existence and make only the MCP deployment project responsible for its lifecycle. |
| Host and container endpoints are confused | Generate loopback and service-DNS endpoints separately from one registry. |
| Unsupported MCP transport | Prefer native HTTP; use Supergateway for stdio; test an actual MCP handshake rather than an HTTP 200 or `/docs` page. |
| Port collisions or stale volumes | Allocate ports explicitly and define backup, upgrade, and cleanup policy before production use. |
  | Arion feature or package drift | Pin inputs, evaluate in CI, and retain generated Compose as the current implementation and escape hatch. |

## Phased migration and validation

1. **Inventory:** list servers, transports, images, ports, volumes, secrets,
   health checks, and current OpenCode entries.
2. **Registry prototype:** define one small registry and generate a native
   HTTP service plus a Supergateway-wrapped stdio service. Validate both
   endpoint forms in OpenCode.
3. **SDK connectivity:** run the disposable-container smoke test from
   `darkGreen-tangerineDream`; confirm the host rootless daemon owns every
   created object and no nested daemon exists.
4. **Compose pilot:** deploy one non-critical MCP service and `McpServers` from
   generated YAML. Check logs, health, restart behavior, volume persistence,
   and removal.
5. **Client derivation:** generate Home Manager OpenCode entries and verify
   host loopback access. Separately verify service-DNS access from a test
   development container.
6. **Compose integration:** attach one existing YAML development project via
   `external: true`; verify it fails clearly when the MCP network is absent
   and succeeds after the MCP stack starts.
7. **Expansion:** migrate remaining MCP services, document rollback to the
   generated Compose path, and add evaluation plus transport smoke tests to CI.
8. **Arion reassessment:** only after several Compose projects expose repeated
   lifecycle or composition problems, prototype an Arion rewrite and compare
   it with the generated Compose workflow.

## Open questions

- What exact host socket path and user-session activation mechanism should the
  SDK use on each supported machine?
- Should the SDK invocation be a user command, a user-scoped systemd unit, or
  another orchestrator?
- Which Arion project owns upgrades and removal of `McpServers`?
- What is the policy for secrets, image pinning, backups, and volume migration?
- Which MCP URL paths and transport variants are stable across all servers?
- Do any services require host publication beyond OpenCode, and how are ports
  allocated without collisions?

## Non-goals

- Replacing the host rootless Docker daemon with Docker-in-Docker.
- Making Home Manager deploy, restart, or remove containers.
- Rewriting every development Compose project during the first migration.
- Supporting mcpo, OpenAPI `/docs`, or arbitrary HTTP endpoints as MCP
  transports.
- Defining a production-grade multi-host orchestrator or Kubernetes platform.
- Solving all secret-management, backup, and image-supply-chain policy in this
  RFC.
