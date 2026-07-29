{
  lib,
  namespace,
}: let
  inherit (lib.${namespace}) source;
in {
  # # Values transformations.
  # Simpler version of a `mapAttrs`: function `f` accepts only value as an argument.
  mapValues = f: attrs: lib.attrsets.mapAttrs (_name: f) attrs;

  # Simpler version of a `mapAttrs`: accepts only prefix as an argument and simply concats prefix and value.
  prefixValues = prefix: attrs: lib.attrsets.mapAttrs (_name: value: "${prefix}${value}") attrs;
  # Simpler version of a `mapAttrs`: accepts only suffix as an argument and simply concats value and suffix.
  suffixValues = suffix: attrs: lib.attrsets.mapAttrs (_name: value: "${value}${suffix}") attrs;

  # Concat to path-like values (string actually).
  concatParentToPathValues = prefix: attrs: lib.attrsets.mapAttrs (_name: value: "${prefix}/${value}") attrs;
  # Concat to path-like values (string actually).
  concatChildToParentValues = suffix: attrs: lib.attrsets.mapAttrs (_name: value: "${value}/${suffix}") attrs;

  # # Keys transformations.
  # Simpler version of a `concatMapAttrs`: function `f` accepts only key as an argument.
  mapKeys = f: attrs: lib.attrsets.concatMapAttrs (name: value: {"${f name}" = value;}) attrs;

  # Simpler version of a `concatMapAttrs`: accepts only prefix as an argument and simply concats prefix and value.
  prefixKeys = prefix: attrs: lib.attrsets.concatMapAttrs (name: value: {"${prefix}${name}" = value;}) attrs;
  # Simpler version of a `concatMapAttrs`: accepts only suffix as an argument and simply concats value and suffix.
  suffixKeys = suffix: attrs: lib.attrsets.concatMapAttrs (name: value: {"${name}${suffix}" = value;}) attrs;

  # Concat to path-like keys (string actually).
  concatParentToPathKeys = prefix: attrs: lib.attrsets.concatMapAttrs (name: value: {"${prefix}/${name}" = value;}) attrs;
  # Concat to path-like keys (string actually).
  concatChildToPathKeys = suffix: attrs: lib.attrsets.concatMapAttrs (name: value: {"${name}/${suffix}" = value;}) attrs;

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
