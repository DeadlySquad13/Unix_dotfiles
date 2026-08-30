# ADR 0001: Select runtime home links through predefined variants

## Status

Accepted

## Context

The Docker images are NixOS systems that boot through `/init`. Docker creates
bind-mount destinations before `/init`, so mounting host data directly in a
managed home directory can shadow image paths and prevent NixOS or Home
Manager activation from working.

The same generic image is used by Compose variants that require different
subsets of host data. Creating every possible Home Manager link leaves unwanted
dangling links; accepting arbitrary source and target paths from a mounted file
would let host configuration direct root-owned filesystem changes.

## Decision

`services.runtime-home-bridge` is a reusable NixOS module. Each image declares
an immutable catalog of mappings and groups them into named variants. Docker
binds host data only below:

```text
/usr/local/<spice-namespace>-/<system-name>/
```

At startup a static systemd oneshot reads a read-only selector:

```json
{ "version": 1, "variant": "green" }
```

The selector may choose only an image-defined variant. The bridge validates its
sources and creates the selected canonical home-directory symlinks before the
matching Home Manager service runs.

The bridge rejects direct canonical-path mountpoints and existing non-symlink
targets. It does not use a systemd generator, `L+`, recursive permission
changes, or automatic `chown` of host mounts.

## Consequences

- Compose can choose a small profile without rebuilding the image.
- Only links required by the selected profile exist.
- New mappings and variants require a Nix configuration change and image
  rebuild, retaining a build-time security boundary.
- Mount permissions remain a host/engine contract and are verified by actual
  consumers; rootless Docker and FUSE must be tested before adding ownership
  mutation.
- Changing a profile requires container recreation, or restarting the bridge
  and the relevant Home Manager service.

## Operational fixes discovered during bring-up

These lessons were learned while making the Green container writable and able to
run its embedded Home Manager configuration.

### Host bind-mount sources must exist with the correct owner before Docker runs

Docker Compose creates missing host bind-mount sources as `root:root` when a
Compose command is elevated, even when the equivalent host path is writable by
the invoking user. Rootful containers then map those sources directly (identity
ut/U/GID mapping), so a host file marked `0755 root:root` is only writable by
container root, and the intended non-root user cannot write OpenCode state.

Symptom: mounts appear as `root:root` inside a container even though the host
directories are `ds13:ds13`.

Fix:

- Use long Compose bind-mount syntax on every host bind and set
  `bind.create_host_path: false`, so Compose refuses to start when a source or
  its parent is missing instead of creating a root-owned directory.
- Add a structured preflight validator
  (`scripts/validate-opencode-mounts.py`) that reads the selected Compose env
  file and, before `docker compose up`, checks each source exists, is a
  directory where required, is owned by the invoking UID, and is writable. The
  relevant Make targets depend on this validator, so a bad mount cannot reach
  Compose.

### Root-owned `~/.cache` breaks embedded Home Manager activation

The NixOS image can include a `~/.cache` directory created during build as
`0:0` with mode `0755`. Docker does not bind any path over it, so it survives.
Home Manager activation creates `~/.cache/.keep` as the user; as a non-root
activation it cannot create that link, and the activation service fails before
installng the managed profile.

Symptom: `home-manager-<user>.service` fails with
`ln: failed to create symbolic link '.../.cache/.keep': Permission denied`, and
programs such as `opencode` are absent.

Fix: the runtime bridge corrects this deterministically before Home Manager
activation, rather than relying on a `systemd-tmpfiles` `Z` rule whose boot
ordering was not guaranteed:

- add `ExecStartPre` entries in the bridge oneshot to `mkdir -p` and `chown`
  `~/.cache` to the configured bridge user before creating the runtime links;
- order the bridge before the `home-manager-<user>.service` unit.

Verification checks inside the container:

```sh
systemctl cat runtime-home-bridge.service        # must show both ExecStartPre
stat -c '%u:%g %a %n' ~/.cache                    # expect <uid>:users 755
systemctl status home-manager-<user>.service
command -v opencode
```

Image build steps can also bake root-owned subdirectories underneath a managed
home directory, for example `~/.config/opencode` containing a root-owned
`node_modules` symlink. Correcting only the top-level managed directory is not
enough: Home Manager still cannot create links inside the deeper root-owned
directory. Keep a per-module owned subdirectory (such as `.config/opencode`) in
the same `managedHomeDirs` list so its ownership is corrected alongside the
parent before activation.
