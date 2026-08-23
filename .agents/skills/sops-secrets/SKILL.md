---
name: sops-secrets
description: This skill should be used when adding, wiring, reviewing, or troubleshooting SOPS-managed secrets and runtime templates in NixOS, Home Manager, or reusable Nix application modules. It covers layered ownership, sops-nix declarations, safe template paths, permissions, overlays, and validation without exposing secret values.
---

# Manage SOPS secrets and templates

Use this skill when an application or service needs a secret, an environment
file, a generated configuration file, or a reusable module interface for one.
Read [`docs/adr/sops-opencode.md`](../../../docs/adr/sops-opencode.md) as a
repository example, but apply the pattern to any application or service rather
than coupling it to a particular client.

## Preserve layered ownership

Separate responsibilities across three layers:

1. **Base system/Home Manager SOPS layer**: import sops-nix, select the vault
   (`sops.defaultSopsFile` or the repository equivalent), establish the age
   key-file default, and provide common policy.
2. **Reusable application module**: declare the application’s
   `config.sops.secrets` keys and `config.sops.templates`, use
   `config.sops.placeholder.<name>` in template content, and expose options for
   consumers and deployment-specific behavior.
3. **Per-system/home overlay**: override the age `keyFile`, secret/template
   owner, group, mode, and path-related values; select the application; and set
   application options such as the runtime template path. Keep machine-specific
   filesystem and service/container details out of the reusable module.

Allow narrower configuration layers to override broader defaults without
duplicating declarations. Treat the reusable module as the owner of the secret
interface and the overlay as the owner of deployment facts.

## Declare values without placing them in Nix

Declare a vault key and reference it through a placeholder:

```nix
sops.secrets.service_api_token = {
  owner = cfg.user;
  group = cfg.group;
  mode = "0400";
};

sops.templates."service.env" = {
  owner = cfg.user;
  group = cfg.group;
  mode = "0400";
  content = ''
    SERVICE_API_TOKEN=${config.sops.placeholder.service_api_token}
  '';
};
```

Use `config.sops.secrets.<name>.path` when a program consumes one extracted
secret file, `config.sops.placeholder.<name>` only inside a sops-nix template,
and `config.sops.templates.<name>.path` when a program consumes the generated
template. Use quoted attribute syntax for names containing punctuation:
`config.sops.templates."service.env".path`.

Keep encrypted values in the SOPS vault. Commit declarations, key names,
template boilerplate, and placeholders only; never put plaintext values in Nix,
generated configuration, examples, logs, shell history, or the Git repository.
Edit the vault as a separate, deliberate operation.

## Design template paths as interfaces

Do not make a reusable module directly assume that a template exists at every
configuration layer. Expose a nullable or otherwise configurable option when a
different module consumes the generated file:

```nix
options.myService.environmentFile = lib.mkOption {
  type = lib.types.nullOr lib.types.str;
  default = null;
  description = "Runtime SOPS-generated environment file.";
};
```

Set that option in the layer that declares or selects the template, commonly
with `config.sops.templates."service.env".path`, and conditionally wire the
consumer only when the option is non-null. This keeps application modules
reusable when a service uses another secret mechanism or no template.

Treat template paths as runtime/out-of-store paths. Repository experience warns
that sops-nix templates are not guaranteed to exist in the Nix store during
evaluation or build; do not force a build-time read of the path (for example,
with `builtins.readFile`). Pass the path through a reusable option or reference
it from a runtime service, activation script, systemd unit, or container
environment instead. Distinguish this from build-time secrets: a derivation
that genuinely requires a secret during build needs a separately reviewed,
explicit mechanism and must not silently turn a runtime secret into a store
input.

## Account for runtime permissions

Choose the extracted file’s `owner`, `group`, `mode`, and destination path for
the process that opens it at runtime. Verify that the parent directory is
traversable and that activation does not place the file in an inaccessible
location. For rootless services and containers, use the effective service UID
and GID, not root or a host-only group; account for UID/GID mapping, bind-mount
paths, container user configuration, and whether the application needs a file
or an environment variable. Prefer least privilege (`0400` or `0440`) and
avoid world-readable modes. Never print the file while diagnosing access.

## Add a new secret

1. Inspect the base SOPS modules, the reusable application module, relevant
   system/home overlays, Make targets, and the vault layout.
2. Declare the stable vault key under `config.sops.secrets`.
3. Declare a template only when the consumer needs a composed file; put
   placeholders, not values, in its content.
4. Expose a module option for the generated path when another module consumes
   it; do not hard-code a template declaration into that consumer.
5. Wire the declaration and option through system and/or Home Manager overlays.
   Override key files, ownership, paths, and application settings there.
6. Edit the encrypted vault separately with `sops`; inspect only metadata or
   key names when possible.
7. Apply the NixOS/Home Manager configuration, then verify the runtime path,
   existence, owner, group, and mode without displaying contents.
8. Test the actual service or container as its runtime user and remove any
   temporary plaintext material.

## Validate and troubleshoot safely

Use repository-specific flake names and targets, and prefer commands that do
not emit secret contents:

```sh
# Evaluate/build the intended system or Home Manager target
nix flake check
nixos-rebuild dry-build --flake .#<system>
home-manager build --flake .#<home>

# Inspect declarations and generated paths, not values
systemctl status sops-nix.service
systemctl cat <service>
stat -c '%U %G %a %n' /run/secrets/<name> /run/secrets/rendered/<template>
namei -l /run/secrets/<name>

# Check syntax and vault metadata without decrypting to stdout
sops --config .sops.yaml --validate <encrypted-file>
```

Use the repository’s actual sops-nix unit name and template directory when they
differ. For failures, check in order: selected vault and age key-file path;
decryption identity and file readability; exact secret key names; template
placeholder spelling; activation/service logs; runtime path existence; parent
directory traversal; UID/GID and mode; and container bind mounts. Inspect Nix
option definitions and evaluated paths, but do not use `cat`, `env`, debug
traces, or logs that could reveal secret values. Confirm that a build does not
contain secret text before publishing or committing it.
