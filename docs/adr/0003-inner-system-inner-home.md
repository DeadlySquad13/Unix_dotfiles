# ADR 0003: Container-embedded inner system and inner home overrides

## Status

Accepted

## Context

Several targets run inside Docker containers. A container is built from a
reusable, deployable NixOS image (the "outer" system) and its matching Home
Manager profile (the "outer" home). For example:

* `darkGreen-tangerineDream` (docker image + home); and
* `NikolaiGogol` (docker image + home).

Once running inside the container, we sometimes need to change configuration
*without* rebuilding the image. The image is immutable and its switch would be
slow or impossible after boot. Instead we define a second, lightweight NixOS
target meant to run *inside* the container — the **inner system** — plus its
matching **inner home**:

* `darkGreen-tangerineDream_inner` (system under
  `systems/x86_64-linux/...` + home `tangerineDream@darkGreen-tangerineDream_inner`); and
* `NikolaiGogol_inner` (system under `systems/x86_64-linux/...` + home `ds13@NikolaiGogol_inner`).

These `_inner` targets are `boot.isContainer` NixOS configurations. They are
switched from inside the running container (for example via
`home-manager switch` / `nixos-rebuild switch`) and layer on top of whatever
the outer image already provides. They act as *overrides*, not replacements.

## Motivation

* Iterate on a containerized machine quickly without rebuilding and reloading
  the whole Docker image.
* Keep the image mostly static and reproducible, while allowing per-boot or
  per-developer tweaks.
* Reuse the same outer image for variants (e.g. `darkGreen-tangerineDream` vs
  `darkGreen-tangerineDream-green`) and apply small inner deltas.

## Decision

For each containerized target we maintain up to **four components**:

| Component | Location | Built when | Purpose |
| --- | --- | --- | --- |
| Outer system | `systems/x86_64-docker/<host>/` | image build | The container image (NixOS). |
| Inner system | `systems/x86_64-linux/<host>_inner/` | inside the running container | In-container override, switched at runtime. |
| Outer home | `homes/x86_64-linux/<user>@<host>/` | image build | Home Manager profile baked into the image. |
| Inner home | `homes/x86_64-linux/<user>@<host>_inner/` | inside the running container | Home Manager override applied in the container. |

The inner system and inner home are **conceptual continuations** of the outer
ones. They differ only in *where* they are switched: the outer components build
the container; the inner components are used when switching while inside the
container. An inner component may:

* enable options the outer image did not (e.g. testing packages,
  `virtualisation.libvirtd`, networking);
* set a different `hostName` such as `darkGreen-tangerineDream` (the physical
  name) rather than `darkGreen-tangerineDream_inner` (the config identity);
* overlay per-boot state through namespaced options.

### Inner components are not self-contained

An inner system does **not** re-declare the outer image's services. It relies
on the outer image's closure still being present at container boot (`/init`
points at the outer system), and only overrides the parts that change inside.
For example, `darkGreen-tangerineDream_inner` does not re-enable the
runtime-home-bridge service; the outer image provides it and its systemd unit
may be absent from `/run/current-system` after the *inner* switch — which is
expected, because the bridge already ran at container boot from the outer
image.

## Consequences

* A container's `/init` may point at the outer system while `/run/current-system`
  points at the inner system after an in-container switch. This is normal and
  should not be treated as a deployment error.
* Services that must run before an in-container `home-manager switch` (such as
  the runtime-home-bridge) are provided by the outer image, not the inner
  system. Verify they ran **at container boot**; do not expect them under the
  inner generation's `systemd.system`.
* PATH and environment for non-login interactive shells (e.g. `docker exec
  … bash`) are established by the image and the *outer* profile; the inner
  override should not assume `/etc/profile` is re-sourced (see ADR 0002 and the
  reusable bash non-login PATH handling).
* Keep the inner delta small and obvious; large divergence defeats the purpose
  of reusing the outer image.

## Examples

* `darkGreen-tangerineDream` / `darkGreen-tangerineDream_inner` with home
  `tangerineDream@darkGreen-tangerineDream` / `tangerineDream@darkGreen-tangerineDream_inner`.
* `NikolaiGogol` / `NikolaiGogol_inner` with home `ds13@NikolaiGogol` /
  `ds13@NikolaiGogol_inner`.

## Synchronization

Update this ADR when adding a new containerized target (a new outer+inner pair),
changing the in-container switch flow, or moving responsibilities between the
outer image and the inner override.
