{
  pkgs,
  ...
}:
# Runs the stdlib-only generator tests in the Nix sandbox. The tests cover the
# Phase 3 ignore-boundary gate, fail-closed link writing, manifest hashing and
# Tier 2 discovery against disposable fixtures.
pkgs.runCommand "test-project-configs-salt" {
  nativeBuildInputs = [pkgs.python3];
} ''
  cp ${../../scripts/project-configs-salt.py} ./project-configs-salt.py
  cp ${../../scripts/test_project_configs_salt.py} ./test_project_configs_salt.py
  cp ${../../scripts/test_project_configs_salt_boundary.py} \
    ./test_project_configs_salt_boundary.py
  python3 test_project_configs_salt.py
  python3 test_project_configs_salt_boundary.py
  echo "project-configs-salt gate tests OK" > "$out"
''
