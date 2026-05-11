{
  lib,
  namespace,
}: let
  inherit (lib.${namespace}) source;
in {
  prefixValues = f: attrs: lib.attrsets.mapAttrs (_name: f) attrs;

  prefixKeys = prefix: attrs: lib.attrsets.concatMapAttrs (name: value: {"${prefix}/${name}" = value;}) attrs;

  # STYLE: Add get-path as an easier separate step. Or add it to `prefixValues`
  # and `prefixKeys`. Use it here only as a last step.
  sourceAttrs = {
    config,
    out-of-store ? false,
    # Wrapper around `lib.ds-omega.source` `get-path` function. Accepts first
    # name and value of current entry inside attrs we're sourcing. Rest arguments are
    # like in `source` function.
    # By default just maps values 1:1.
    get-path ? { name, value }: _p : value,
    recursive ? false,
  }: attrs:
    lib.attrsets.mapAttrs (
      name: value:
        source {
          inherit config out-of-store recursive;
          get-path = get-path { inherit name; inherit value; };
        }
    )
    attrs;
}
