{ lib, namespace }:
let
  inherit (lib.${namespace}) source;
in
{
  prefixValues = f: attrs: lib.attrsets.mapAttrs (_name: value: f value) attrs;

  prefixKeys =
    prefix: attrs: lib.attrsets.concatMapAttrs (name: value: { "${prefix}/${name}" = value; }) attrs;

  sourceAttrs =
    {
      config,
      out-of-store ? false,
    }:
    attrs:
    lib.attrsets.mapAttrs (
      _name: value:
      source {
        inherit config out-of-store;
        get-path = _p: value;
      }
    ) attrs;
}
