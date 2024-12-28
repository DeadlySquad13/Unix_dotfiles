{
  namespace,
  inputs,
  lib,
  ...
}: let
  inherit (inputs.nixpkgs.lib) attrsets strings;
  inherit (lib.${namespace}) disabled enabled;
in {
  # Just some syntax sugar.
  # Reference: https://github.com/jakehamilton/config/blob/f8f8d3d70a7ef58f9d030fe36d35caa7054fdcec/lib/module/default.nix
  enabled = {
    ## Quickly enable an option.
    ##
    ## ```nix
    ## services.nginx = enabled;
    ## ```
    ##
    #@ true
    enable = true;
  };

  disabled = {
    ## Quickly disable an option.
    ##
    ## ```nix
    ## services.nginx = enabled;
    ## ```
    ##
    #@ false
    enable = false;
  };

  # Construct module with option and config attrs
  # See: https://github.com/snowfallorg/lib/issues/44#issuecomment-1929033007
  # https://github.com/nix-community/home-manager/blob/master/modules/programs/ranger.nix
  mkIfEnabled = {
    config, # Home config with `enable` settings.
    # Category and name of the item:
    # `modules/home/apps/<category>/<name>/default.nix.
    # Category can be nested:
    # category = "development.nix" will result in
    # `...aps/development/nix/<name>/default.nix`
    category,
    name,
    extraPredicate ? { modules-cfg, module-cfg }: true
  }:
  # What you want to get when the module is enabled (module contents - app's configuration).
  module: let
    inherit (lib) mkIf;

    modules-cfg = config.lib.${namespace}.modules or {};
    categories = strings.splitString "." category;
    category-cfg = attrsets.attrByPath categories {} modules-cfg;
    module-cfg = category-cfg.${name} or {};

    # TODO: In a similar to `options` manner, config should be recursively
    # iterated: now we have only deepest sub-category options applied. For
    # example, in config:
    # {
    #   tools = {
    #     enable = false;
    #     ranger.enable = true;
    #   }
    #   development = {
    #     enable = false;
    #     nix = {
    #       enable = true;
    #       alejandra.enable = true;
    #     };
    #   }
    # }
    #
    # ranger will be disabled because tools is disabled but alejandra will not
    # be disabled even though a whole layer of development is disabled because
    # only the deepest category (nix) is taken into account.
    # config = mkIf (category-cfg ? enable && category-cfg.enable && module-cfg ? enable && module-cfg.enable) module;
    category-enabled = category-cfg ? enable && category-cfg.enable;
    # Enable or disable module if it has an explicitly stated `enable`.
    # Otherwise look at the category.
    module-enabled = if module-cfg ? enable then module-cfg.enable else category-enabled;
  in {
    # TODO: Ideally we should recurse over category parts: output ->
    # { ...output, options = output.options.${category-part} }.
    # Now we have: `options."development.nix".<name>`
    # but want: `options.development.nix.<name>`
    # For inspiration see https://github.com/NixOS/nixpkgs/blob/05405724efa137a0b899cce5ab4dde463b4fd30b/lib/attrsets.nix#L65
    options.${namespace}.${category}.${name} = with lib.types; {
      enable = mkBoolOpt false "Whether or not to enable ${name}.";
    };

    config = mkIf (module-enabled && extraPredicate { inherit modules-cfg; inherit module-cfg; }) module;
  };


  # Consider variant enabled if it's not stated otherwise. May change in the
  # future hence this functions must be used.
  mkIfDevEnabled = { module-cfg, ... }: if module-cfg ? dev then module-cfg.dev else true;
  mkIfStageEnabled = { module-cfg, ... }: if module-cfg ? stage then module-cfg.stage else true;
}
