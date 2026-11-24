# Datapath op catalog for the two Manilov network profiles.
#
# Each profile is an *ordered list* of operations in execution order. Values
# owned by the host are expressed as parameter references:
#   { "$param" = "<dotted.path>"; }
# The applier resolves them against `marker.params` before acting. Image-owned
# constants (br0, manilov_vm, tap*) stay literal so the image cannot be told to
# write a host interface name.
let
  param = path: {"$param" = path;};

  # Drop-only isolation rules from ADR 0010. Both tables keep `policy accept`
  # and only carry scoped drops; no base-chain policy drop, no permit, and no
  # `flush ruleset` is emitted here.
  nftRules = [
    "table bridge manilov_vm {"
    "  chain forward {"
    "    type filter hook forward priority -10; policy accept;"
    "    iifname \"tap*\" ether saddr != { $VM_MACS } drop"
    "    iifname \"tap*\" ip saddr != { $VM_PREFIXES } drop"
    "    iifname \"tap*\" ip6 saddr != { $VM_PREFIX6S } drop"
    "    iifname \"tap*\" oifname \"tap*\" drop"
    "  }"
    "}"
    "table inet manilov_vm {"
    "  chain forward {"
    "    type filter hook forward priority -10; policy accept;"
    "    iifname \"tap*\" ip saddr != { $VM_PREFIXES } drop"
    "    iifname \"tap*\" ip6 saddr != { $VM_PREFIX6S } drop"
    "    iifname \"tap*\" oifname \"tap*\" drop"
    "  }"
    "}"
  ];
in {
  # WLAN-friendly path: the VM reaches the LAN through a proxy-ARP tap.
  proxyarp = [
    {
      op = "link.add";
      name = param "datapath.tap";
      type = "tap";
    }
    {
      op = "link.up";
      name = param "datapath.tap";
    }
    {
      op = "sysctl.set";
      # Path segments; the tap segment is resolved from the marker at apply
      # time, so the image never hardcodes a host interface name.
      key = ["net" "ipv4" "conf" (param "datapath.tap") "proxy_arp"];
      value = 1;
    }
    {
      op = "addr.add";
      dev = param "datapath.tap";
      address = param "management.address";
    }
    {
      op = "nft.load";
      rules = nftRules;
    }
  ];

  # Bridged path: br0 owns L3, the uplink is enslaved, and the MAC is pinned.
  bridge = [
    {
      op = "assert.linkMac";
      name = param "uplink.name";
      mac = param "uplink.permanentMac";
    }
    {
      op = "link.add";
      name = "br0";
      type = "bridge";
    }
    {
      op = "link.set";
      name = "br0";
      mac = param "uplink.permanentMac";
    }
    {
      op = "link.master";
      name = param "uplink.name";
      master = "br0";
    }
    {
      op = "link.up";
      name = "br0";
    }
    {
      op = "addr.add";
      dev = "br0";
      address = param "management.address";
    }
    {
      op = "route.add";
      dev = "br0";
      destination = "default";
      gateway = param "management.gateway";
    }
    {
      op = "nft.load";
      rules = nftRules;
    }
  ];
}
