{
  pkgs,
  lib,
  ...
}:
# Runs the stdlib-only `.stignore` merge tests in the Nix sandbox, then an
# integration pass that merges the *real* derived pattern list into a fixture
# `.stignore` shaped like the one observed on @creamsoda.
#
# Phase 1 covers create/append/preserve, exact-line semantics, newline style,
# idempotency, `--dry-run`, `--check`, the missing-parent skip, and the atomic
# replace. Phase 2 asserts ordering, uniqueness, exact-one-line membership,
# `--check` and byte-identical second runs against the real list, and that the
# symlinked project taxonomy expands each logical pattern to its real location.
let
  projectConfigs = import ../../lib/project-configs {inherit lib;};

  fixtureRoot = "/fixture/Projects";
  fixtureStructures = projectConfigs.projectStructures {
    projectsRoot = fixtureRoot;
    rutubeProjectsRoot = "${fixtureRoot}/--professional/Rutube__";
    pathIsDirectory = _: false;
  };
  derivedPatterns = projectConfigs.ignorePatterns fixtureStructures;

  # Mirrors the module's `stignoreBasePatterns` default. Kept local because a
  # standalone check has no Home Manager option defaults to read.
  basePatterns = [
    "node_modules"
    "/.artifact"
    ".local-artifacts"
    ".artifacts--processed"
  ];

  allPatterns = basePatterns ++ derivedPatterns;

  mergeArgString = lib.escapeShellArgs (
    ["--file" "Projects/.stignore"]
    ++ lib.concatMap (p: ["--pattern" p]) allPatterns
  );
  allPatternsArgString = lib.escapeShellArgs allPatterns;
  derivedArgString = lib.escapeShellArgs derivedPatterns;

  # Independent static mapping for the fixture: every AutoHub logical pattern
  # must gain the `/auto-hub/...` variant. This does not reuse the Python
  # expansion, so a consistently wrong expansion cannot satisfy the check.
  autoHubPrefix = "/--professional/Rutube__/AutoHub/";
  autoHubRealPatterns =
    map
    (p: "/auto-hub/" + lib.removePrefix autoHubPrefix p)
    (builtins.filter (p: lib.hasPrefix autoHubPrefix p) derivedPatterns);
  autoHubRealArgString = lib.escapeShellArgs autoHubRealPatterns;

  script = ../../scripts/stignore-merge.py;
  testScript = ../../scripts/test_stignore_merge.py;

  # Print the expected expanded list for a given root. The function lives in
  # the copied script, so this exercises the same code the writer runs.
  expectedPy = ''
import importlib.util
import sys

spec = importlib.util.spec_from_file_location(
    "stignore_merge", "./stignore-merge.py"
)
assert spec is not None and spec.loader is not None
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

for pattern in mod.expand_alias_patterns(sys.argv[2:], sys.argv[1]):
    print(pattern)
'';


in
  pkgs.runCommand "test-stignore-merge" {
    nativeBuildInputs = [pkgs.python3];
    inherit derivedPatterns;
  } ''
    set -euo pipefail

    # --- Phase 1: unit tests -------------------------------------------------
    cp ${script} ./stignore-merge.py
    cp ${testScript} ./test_stignore_merge.py
    python3 test_stignore_merge.py

    # --- Phase 2: integration with the real derived list ---------------------
    # Physical tree plus the alias symlink that Syncthing never traverses.
    mkdir -p Projects
    printf 'node_modules\n/.artifact\n' > Projects/.stignore
    mkdir -p Projects/auto-hub/_configs
    printf 'key: value\n' > Projects/auto-hub/_configs/Main.yml
    mkdir -p Projects/auto-hub/_scripts
    mkdir -p Projects/--professional/Rutube__
    ln -s ../../auto-hub Projects/--professional/Rutube__/AutoHub

    python3 - "$PWD/Projects" ${allPatternsArgString} \
      <<'PY' > expected.txt
    ${expectedPy}
    PY

    python3 ./stignore-merge.py \
      --projects-root "$PWD/Projects" ${mergeArgString}

    # Exact expanded list, in order, including every real variant.
    diff -u expected.txt Projects/.stignore

    # The pre-existing lines stay first and unchanged.
    first=$(sed -n '1p' Projects/.stignore)
    second=$(sed -n '2p' Projects/.stignore)
    if [ "$first" != "node_modules" ] || [ "$second" != "/.artifact" ]; then
      echo "pre-existing lines changed or reordered: [$first] [$second]" >&2
      exit 1
    fi

    # The same arguments pass `--check` afterwards.
    python3 ./stignore-merge.py \
      --projects-root "$PWD/Projects" ${mergeArgString} --check

    # No duplicate lines at all.
    duplicates=$(sort Projects/.stignore | uniq -d)
    if [ -n "$duplicates" ]; then
      echo "duplicate .stignore lines:" >&2
      echo "$duplicates" >&2
      exit 1
    fi

    # Every logical derived pattern appears exactly once.
    for pattern in ${derivedArgString}; do
      count=$(grep -Fx -- "$pattern" Projects/.stignore | wc -l)
      if [ "$count" -ne 1 ]; then
        echo "logical $pattern appears $count time(s), expected 1" >&2
        exit 1
      fi
    done

    # Every AutoHub real variant also appears exactly once. The list is the
    # static prefix mapping above, independent of the Python expansion.
    for pattern in ${autoHubRealArgString}; do
      count=$(grep -Fx -- "$pattern" Projects/.stignore | wc -l)
      if [ "$count" -ne 1 ]; then
        echo "real $pattern appears $count time(s), expected 1" >&2
        exit 1
      fi
    done

    # The alias/real pair is present for the AutoHub tree.
    grep -Fx -- "/--professional/Rutube__/AutoHub/_scripts" \
      Projects/.stignore > /dev/null
    grep -Fx -- "/auto-hub/_scripts" Projects/.stignore > /dev/null

    # A second run is byte-identical.
    sha256sum Projects/.stignore > before.sha
    python3 ./stignore-merge.py \
      --projects-root "$PWD/Projects" ${mergeArgString} > /dev/null
    sha256sum -c before.sha

    # --- Phase 2b: `_scripts` itself is an absolute store-like symlink ------
    # The entry must not be resolved: the pattern stays `/auto-hub/_scripts`,
    # never a `/nix/store/...` path.
    mkdir -p Projects-link
    printf 'node_modules\n/.artifact\n' > Projects-link/.stignore
    mkdir -p Projects-link/auto-hub/_configs
    printf 'key: value\n' > Projects-link/auto-hub/_configs/Main.yml
    mkdir -p store-scripts
    ln -s "$PWD/store-scripts" Projects-link/auto-hub/_scripts
    mkdir -p Projects-link/--professional/Rutube__
    ln -s ../../auto-hub Projects-link/--professional/Rutube__/AutoHub

    python3 - "$PWD/Projects-link" ${allPatternsArgString} \
      <<'PY' > expected-link.txt
    ${expectedPy}
    PY
    python3 ./stignore-merge.py \
      --file Projects-link/.stignore --projects-root "$PWD/Projects-link" \
      ${lib.escapeShellArgs (
        lib.concatMap (p: ["--pattern" p]) allPatterns
      )}
    diff -u expected-link.txt Projects-link/.stignore
    grep -Fx -- "/auto-hub/_scripts" Projects-link/.stignore > /dev/null
    if grep -F -- "/nix/store/" Projects-link/.stignore; then
      echo "entry symlink was resolved into /nix/store/" >&2
      exit 1
    fi

    echo "stignore-merge tests OK (symlink-aware expansion)" > "$out"
  ''
