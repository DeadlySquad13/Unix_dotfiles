# ADR 0010: Manilov network ownership — host FORWARD permit, image drops

- Status: Accepted
- Date: 2026-11-03
- Supersedes: the "VM-path FORWARD rules" row and the firewall-split clause of
  the 2026-11-02 contract. The earlier citations
  `docs/adr/0006-ManilovNetworkOwnership.md` and
  `docs/adr/0007-ContainerDatapathOwnership.md` were placeholders: those files
  never existed in this repository, whose `0006` and `0007` are unrelated ADRs
  and remain untouched. Manilov network ownership is now this ADR `0010`;
  container datapath ownership is [ADR 0011](0011-container-datapath-ownership.md).
- Related: [ADR 0011](0011-container-datapath-ownership.md),
  [ADR 0001](0001-runtime-home-bridge.md),
  [ADR 0003](0003-inner-system-inner-home.md)
- Scope: Manilov MVP task `MANILOV-MVP-001`, project `Unix_dotfiles`, target
  `@Manilov`: host vs image ownership of the VM-path FORWARD policy, canonical
  handoff state paths, and the numbering/remap of the superseded Manilov
  network-ownership placeholders.

The repository-generic layering and ownership rules live in `../../.agents/AGENTS.md`;
this ADR owns the concrete Manilov table names, chains, rules, paths, and
commands.

## Context

The image runs with `network_mode: host` and `privileged: true`. It owns `br0`,
the uplink enslavement, the L3 move, the MAC pin, `tap0`/proxyARP, and the VM
tap attachment. The host owns the global firewall, SSH/`INPUT_PROTECT`,
`DOCKER-*`, the one-time relinquish, and the rescue.

nftables base chains at one hook are all traversed. An accept in one base chain
is not final; a drop (including a base-chain policy drop) is final. `jump`/`goto`
cannot cross tables. With `br_netfilter` and `bridge-nf-call-iptables=1`,
bridged frames also traverse the IPv4 forward hook. Therefore an image-owned
table `inet manilov_vm` with `policy accept` cannot override the host's table
`ip filter` chain `FORWARD` policy drop.

The host's IPv4 filter table is family `ip` on `@terra` (research Cell 6). The
applier therefore requires the jump in **every** `filter` `FORWARD` chain whose
policy is `drop` (family `ip` or `inet`); if both exist, both need the jump.
IPv6 on `@terra` is link-local only, so the `ip`-family permit
governs IPv4 forwarding; the image's `inet manilov_vm` drops still apply IPv6
isolation.

## Decision

### D1 — Split the VM-path FORWARD rules

Permit is host-owned. Host provisioning writes a scoped accept into
`table ip filter`, chain `MANILOV_FORWARD`, jumped from `FORWARD` before the
DOCKER jumps:

```nft
table ip filter {
  chain FORWARD {
    iifname "br0"  oifname "br0"  jump MANILOV_FORWARD
    iifname "tap*" oifname "eth1" jump MANILOV_FORWARD
    iifname "eth1" oifname "tap*" jump MANILOV_FORWARD
    jump DOCKER-USER
    jump DOCKER-FORWARD
    # policy drop unchanged
  }
  chain MANILOV_FORWARD { accept }
}
```

The bridged permit is `br0`<->`br0` because `br_netfilter` reports bridge ports
as the bridge; the routed proxyARP permit is `tap*`<->uplink. Interface names
are marker-declared (`net.interfaces{uplink,bridge,tap_glob}`), not image
constants. `tap_glob` lets a new VM be added without a host rewrite; per-VM
drops enforce the allowed MAC/source. The host grant is idempotent (one
`nft -f` transaction, chain flushed and repopulated, jump rules exactly once,
backup before first write) and is re-applied at boot and on a bounded timer by
a bootstrap unit.

Deny is image-owned. The image writes anti-spoof/isolation drops in dedicated
tables, both `policy accept` with explicit scoped drops:

```nft
table bridge manilov_vm {
  chain forward {
    type filter hook forward priority -10; policy accept;
    iifname "tap*" ether saddr != { $VM_MACS } drop
    iifname "tap*" ip  saddr != { $VM_PREFIXES } drop
    iifname "tap*" ip6 saddr != { $VM_PREFIX6S } drop
    iifname "tap*" oifname "tap*" drop
  }
}
table inet manilov_vm {
  chain forward {
    type filter hook forward priority -10; policy accept;
    iifname "tap*" ip  saddr != { $VM_PREFIXES } drop
    iifname "tap*" ip6 saddr != { $VM_PREFIX6S } drop
    iifname "tap*" oifname "tap*" drop
  }
}
```

The `$VM_MACS`, `$VM_PREFIXES`, and `$VM_PREFIX6S` placeholders are values
rendered from the marker `params` at apply time; they are not shell environment
variables.

Neither table may carry a permit or a base-chain policy drop. The image never
writes the host `filter` table; the host never writes the image tables.

### D2 — Canonical state paths

`/run/manilov-network/owner.lock` (per boot) and
`/var/lib/manilov-network/owner.json` (durable) are the canonical state paths.
They follow the accepted 2026-11-02 naming decision: `manilov-network` is the
full name for the service units, binary, module, runtime directory and state
directory; the short form `manilov-net` is retired. The host-provisioned marker
stays at `/etc/manilov/marker.json`, because it is not a unit artifact.

Superseded: `/run/manilov-net/` and `/var/lib/manilov-net/` (the older contract
text) and `/run/manilov/owners/` (the handoff draft). Do not reintroduce them.

### D3 — Numbering

This file is `0010`; container datapath is `0011`. The old `0006`/`0007` labels
are stale; repo ADRs `0001`-`0009` are untouched.
The `0010`/`0011` filenames above are the repository files; the Logseq contract
keeps only the label remap.

## Guarantees

- `INPUT_PROTECT` is byte-identical before and after an image apply; the host
  `FORWARD` policy stays drop.
- SSH `9222` is unaffected; the permit is `FORWARD`-only.
- `DOCKER-USER` and `DOCKER-FORWARD` are untouched and still reached for
  non-Manilov traffic.
- One writer per table: the host writes `ip filter`; the image writes the
  `manilov_vm` tables.

## Prohibited

- The image writing, flushing, or adding a jump to `table ip filter`.
- A base-chain policy drop in any `manilov_vm` table; an accept presented as a
  permit.
- Host `FORWARD` policy accept, or an accept broader than the declared
  `{br0, tap*}` <-> uplink pairs.
- Disabling `bridge-nf-call-*` or changing `rp_filter` to make forwarding work.
- A datapath change (macvtap, passt, routed netns) without a new ADR.

## Failure modes

- Host permit missing after TOS reassertion: image status reads
  `nft list ruleset`, reports `host-permit-missing`, fails closed, does not
  self-heal.
- Host reconciler failure: bounded retries; SSH and rescue are unaffected.
- Interface drift: check fails closed before apply.
- Extra forward base chain with policy drop: status flags it.

## Acceptance tests

- T1: VM->LAN ping/TCP succeeds; `MANILOV_FORWARD` counters increment.
- T2: LAN->VM forwarding succeeds.
- T3: SSH `9222` from `192.168.100.0/24` works; `INPUT_PROTECT` hash unchanged.
- T4: `nft list ruleset` shows exactly host `ip filter` (`INPUT_PROTECT`,
  `DOCKER-*`, `MANILOV_FORWARD`) and the image `manilov_vm` tables; no image
  rules in the host table.
- T5: rollback restores the captured pre-state.
- T6: passes after container recreate, reboot, and simulated TOS reassertion.

## Migration

1. Host grant + reconciler (marker `net.interfaces`).
2. Image S7: drop-only `manilov_vm` tables, check the host permit.
3. Image S9: bridge/proxyARP apply.
4. Parity and end-to-end tests.

## Consequences

- Host provisioning must land before the image applies drop-only tables; a
  missing host permit leaves the image failing closed instead of silently
  self-healing.
- The host must keep the boot/timer reconciler so the permit survives TOS
  reassertion and reboot.
- Any datapath redesign is now a new ADR, not an image-local change.
- Forbidden by construction: the image touching the host `filter` table, any
  `manilov_vm` base-chain policy drop or permit, a host `FORWARD` policy accept,
  and disabling bridge filtering or `rp_filter` to make forwarding work.

## Rollback

Remove the host grant (chain + jumps, restore backup) and the `manilov_vm`
tables; no other host state is touched.

## Synchronization

Update this ADR when changing the nft table/chain names, the host permit scope,
the marker `net.interfaces` or `params` contract, the canonical state paths,
the reconciler/boot behavior, the acceptance tests, or the datapath. Keep
`../../.agents/AGENTS.md` limited to generic layering and ownership rules and link here.
Container datapath ownership changes belong in
[ADR 0011](0011-container-datapath-ownership.md).
