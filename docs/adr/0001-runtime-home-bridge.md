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
