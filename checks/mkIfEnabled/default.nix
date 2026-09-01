{
  pkgs,
  lib,
  namespace,
  inputs,
  ...
}: let
  # Import repo `lib/modules` directly (same pattern as the paths check), mocking
  # the namespace with the `disabled`/`enabled` sugar it reads at the top.
  modulesLib = import ../../lib/modules {
    inherit inputs namespace;
    lib = lib // {
      ${namespace} = {
        disabled = { enable = false; };
        enabled = { enable = true; };
      };
    };
  };

  inherit (modulesLib) mkIfEnabled mkIfDevEnabled mkIfStageEnabled mkIfProdEnabled;

  # The module body we pass; a recognizable marker to assert enablement.
  body = {
    markers = "enabled-body";
    config.assertThisRuns = true;
  };

  # Evaluate `mkIfEnabled` with a mock `config.lib.${namespace}.modules` tree.
  run = {
    category,
    name,
    modules,
    extraPredicate ? null,
  }: let
    mockConfig = { lib.${namespace}.modules = modules; };
    args = {
      inherit category name;
      config = mockConfig;
    } // (lib.optionalAttrs (extraPredicate != null) { inherit extraPredicate; });
  in
    mkIfEnabled args body;

  # Assert helper: module is "enabled" iff the condition is true.
  isEnabled = result: result.config.condition == true;

  # --- Cases ---

  # 1. Category enabled, no explicit module enable → module enabled.
  assertCategoryEnabled =
    isEnabled (run {
      category = "tools";
      name = "ranger";
      modules.tools = { enable = true; };
    });

  # 2. Category disabled, no explicit module enable → module disabled.
  assertCategoryDisabled =
    !isEnabled (run {
      category = "tools";
      name = "ranger";
      modules.tools = { enable = false; };
    });

  # 3. Category disabled but module explicitly enabled → module enabled
  #    (this is the "children override the category" case from cli-utility/bash).
  assertModuleOverridesCategory =
    isEnabled (run {
      category = "cli-utility";
      name = "bash";
      modules.cli-utility = {
        enable = false;
        bash = { enable = true; };
      };
    });

  # 4. Category enabled but module explicitly disabled → module disabled.
  assertModuleDisablesFromEnabledCategory =
    !isEnabled (run {
      category = "cli-utility";
      name = "bash";
      modules.cli-utility = {
        enable = true;
        bash = { enable = false; };
      };
    });

  # 5. Nested category enabled, sub-module no explicit enable → enabled.
  assertNestedCategoryEnabled =
    isEnabled (run {
      category = "development.nix";
      name = "alejandra";
      modules.development.nix = { enable = true; };
    });

  # 6. Nested category disabled, sub-module explicitly enabled → enabled.
  assertNestedModuleOverridesCategory =
    isEnabled (run {
      category = "development.nix";
      name = "alejandra";
      modules.development.nix = {
        enable = false;
        alejandra = { enable = true; };
      };
    });

  # 7. Nested category enabled, sub-module explicitly disabled → disabled.
  assertNestedModuleDisablesFromEnabled =
    !isEnabled (run {
      category = "development.nix";
      name = "alejandra";
      modules.development.nix = {
        enable = true;
        alejandra = { enable = false; };
      };
    });

  # 8. Category missing entirely → module disabled.
  assertMissingCategory =
    !isEnabled (run {
      category = "nonexistent";
      name = "foo";
      modules = { };
    });

  # 9. extraPredicate returns false → module disabled even if enabled.
  assertExtraPredicateGates =
    !isEnabled (run {
      category = "tools";
      name = "ranger";
      modules.tools = { enable = true; };
      extraPredicate = { modules-cfg, module-cfg }: false;
    });

  # 10. extraPredicate returns true → module enabled.
  assertExtraPredicateAllows =
    isEnabled (run {
      category = "tools";
      name = "ranger";
      modules.tools = { enable = true; };
      extraPredicate = { modules-cfg, module-cfg }: true;
    });

  # 11. mkIfDevEnabled: dev = true → true.
  assertDevEnabled =
    mkIfDevEnabled { module-cfg = { dev = true; }; };
  assertDevDefault =
    mkIfDevEnabled { module-cfg = { }; };

  # 12. mkIfStageEnabled: stage = false → false.
  assertStageDisabled =
    !mkIfStageEnabled { module-cfg = { stage = false; }; };

  # 13. mkIfProdEnabled: prod = true → true, prod = false → false.
  assertProdEnabled =
    mkIfProdEnabled { module-cfg = { prod = true; }; };
  assertProdDisabled =
    !mkIfProdEnabled { module-cfg = { prod = false; }; };

in
  assert assertCategoryEnabled;
  assert assertCategoryDisabled;
  assert assertModuleOverridesCategory;
  assert assertModuleDisablesFromEnabledCategory;
  assert assertNestedCategoryEnabled;
  assert assertNestedModuleOverridesCategory;
  assert assertNestedModuleDisablesFromEnabled;
  assert assertMissingCategory;
  assert assertExtraPredicateGates;
  assert assertExtraPredicateAllows;
  assert assertDevEnabled;
  assert assertDevDefault;
  assert assertStageDisabled;
  assert assertProdEnabled;
  assert assertProdDisabled;
  pkgs.runCommand "test-mkIfEnabled" { } ''
    echo "mkIfEnabled tests OK" > "$out"
  ''
