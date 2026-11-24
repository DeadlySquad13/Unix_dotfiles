# Manilov network fixtures

Marker fixtures used by the checkpoint-C NixOS checks.

## Selector digest canonicalization

The applier canonicalizes the selector as `jq -jS -c` (sorted keys, compact,
no trailing newline) and hashes exactly the same bytes Nix's `builtins.toJSON`
produces. Recompute a marker digest with:

```sh
jq -jS -c -n \
  --arg schema "manilov.network.marker/v1" \
  --arg profile "proxyarp" \
  --arg role "owner" \
  --arg id "nikolaigogol" \
  '{schema:$schema,profile:$profile,role:$role,owner:{kind:"image",id:$id}}' \
  | sha256sum \
  | awk '{print "sha256:" $1}'
```

The same command with `profile=bridge` or `role=consumer` produced the values
in `terra.json` and `consumer.json`.

## Local smoke test

`smoke.sh` builds `.#manilov-network`, prepends the fake tools in `fake-bin/`
to its `PATH`, and drives the applier inside a throwaway `--root`:

```sh
tests/fixtures/manilov/smoke.sh terra   # full bridge lifecycle
tests/fixtures/manilov/smoke.sh salt    # proxyarp check + resolved plan
```

The fake `ip`/`nft`/`ss`/systemd tools never touch the real network. Set
`MANILOV_FAKE_LOG` (the smoke script points it into the sandbox) to record
their invocations.

## Host-permit fixtures (`nft -j list ruleset` shapes)

The applier's `host-permit` check looks for a jump to `MANILOV_FORWARD` in the
`FORWARD` chain of a `filter` table whose chain policy is `drop` (base chains
only can carry a policy). It accepts both the `ip` and `inet` families.

| Fixture | Shape | Expected `host-permit` |
| --- | --- | --- |
| `nft-host-permit.json` | `ip filter`, `FORWARD` `policy drop` | 0 |
| `nft-host-permit-inet.json` | `inet filter`, `FORWARD` `policy drop` (portability) | 0 |
| `nft-host-permit-no-drop.json` | `ip filter`, `FORWARD` `policy accept`, jump present | 7 |

`nft-host-permit.json` mirrors the real `@terra` host (family `ip`).

## Optional netlink fixture shape

`--netlink-fixture` is read instead of `ip` for link/address/route data. The
applier accepts:

```json
{
  "links": [
    {"ifname": "eth-test0", "address": "02:00:00:00:00:02", "operstate": "UP", "carrier": true}
  ],
  "addresses": [
    {"ifname": "br0", "address": "198.51.100.10/24"}
  ],
  "routes": [
    {"dst": "default", "gateway": "198.51.100.1", "dev": "br0"}
  ],
  "sshd": true
}
```
