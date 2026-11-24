# ADR 0011: Container datapath ownership — one datapath owner per host

- Status: Accepted
- Date: 2026-11-03
- Supersedes: the stale citation
  `docs/adr/0007-ContainerDatapathOwnership.md`. That label was a placeholder:
  no such file ever existed in this repository, whose `0007` is an unrelated
  ADR and remains untouched. Container datapath ownership is now this ADR
  `0011`; the Manilov network ownership split is
  [ADR 0010](0010-manilov-network-ownership.md).
- Related: [ADR 0010](0010-manilov-network-ownership.md),
  [ADR 0003](0003-inner-system-inner-home.md)
- Scope: Manilov MVP task `MANILOV-MVP-001`, project `Unix_dotfiles`, target
  `@Manilov`: the single-datapath-owner rule for containers that run with host
  networking, the owner marker/lock/state contract, and multi-VM sharing under
  one owner.

The repository-generic layering and ownership rules live in `../../.agents/AGENTS.md`;
this ADR owns the concrete container datapath owner marker, lock paths, and
multi-VM contract.

## Context

`@NikolaiGogol` runs with `network_mode: host` and `privileged: true`; every
such container shares the `@terra` network namespace. Two appliers would race
on the same `br0`, `eth1`, MAC pin, and nft state.

## Decision

- Exactly one datapath owner per host; any number of consumers.
- The host-provisioned marker carries `role: owner|consumer` plus `owner.id`,
  `owner.container`, and `owner.image`. Only `role: owner` may
  apply/confirm/rollback; consumers are read-only check/status. The image
  cannot promote itself.
- The owner holds an exclusive `flock`/`O_EXCL` lock at
  `/run/manilov-network/owner.lock` and records
  `/var/lib/manilov-network/owner.json` (owner id, container, image digest,
  boot id, container start id) (the full `manilov-network` naming from the
  accepted 2026-11-02 decision; `manilov-net` is retired).
- `check` fails closed when another owner holds the lock, the marker role is
  wrong, or a conflicting L3 owner exists. A stale lock is reclaimable only by
  the same `owner.id` after the boot/container check.
- Multiple VMs share the owner's `br0`; each VM gets a tap and MAC, and all taps
  are rendered by the owner. Additional VMs are VM-path entries, not owners.
- The host `FORWARD` permit ([ADR 0010](0010-manilov-network-ownership.md)) is
  firewall policy, not datapath ownership; it does not make the host a datapath
  owner.

## Guarantees and prohibited

- One writer per host-global object: the owner writes `br0`/tap/L3 and the
  image tables; the host writes only the relinquish and the `FORWARD` permit.
- Prohibited: a second `role: owner` with a different `owner.id`; a consumer
  running apply/rollback; the image writing the host `filter` table; using any
  superseded path (`/run/manilov/owners/`, `/run/manilov-net/`,
  `/var/lib/manilov-net/`).

## Failure modes

- Second owner: fails closed on the lock/marker.
- Stale lock after reboot: the same `owner.id` may reclaim after the boot
  check.
- Owner crash mid-apply: nft transactions are atomic; rollback is idempotent.

## Acceptance tests

- A second `role: owner` with a different `owner.id` fails closed.
- A consumer cannot apply/rollback.
- Multiple VMs share `br0` with taps rendered only by the owner.
- The lock and `owner.json` use the canonical paths.

## Consequences

- Adding a VM is a VM-path entry under the existing owner, never a new owner;
  this keeps `br0`, `eth1`, the MAC pin, and nft state single-writer.
- Host-networked containers must agree on the marker before any datapath
  action; a consumer is read-only even when it has the same privileges.
- The owner lock lifetime is tied to the boot id and container start id, so
  reboot recovery requires the same `owner.id`.
- The host `FORWARD` permit does not grant or imply datapath ownership.
- Forbidden by construction: a second owner with a different `owner.id`, a
  consumer applying or rolling back, the image writing the host `filter` table,
  and use of any superseded path (`/run/manilov/owners/`, `/run/manilov-net/`,
  `/var/lib/manilov-net/`).

## Rollback

Owner rollback is idempotent: remove the image tables, taps, and `br0`, and
restore L3; release the lock only after the state is rolled back.

## Synchronization

Update this ADR when changing the owner marker fields, the lock or
`owner.json` paths, the multi-VM sharing model, or the owner/consumer
permission rules. Keep `../../.agents/AGENTS.md` limited to generic layering and
ownership rules and link here. Firewall permit changes belong in
[ADR 0010](0010-manilov-network-ownership.md).
