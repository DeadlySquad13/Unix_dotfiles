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
# `--check` and byte-identical second runs against the real list.
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
  basePatterns = ["node_modules" "/.artifact" ".local-artifacts" ".artifacts--processed"];

  allPatterns = basePatterns ++ derivedPatterns;
  expectedLineCount = builtins.length (lib.unique allPatterns);

  mergeArgString = lib.escapeShellArgs (
    ["--file" "Projects/.stignore"] ++ lib.concatMap (p: ["--pattern" p]) allPatterns
  );
  derivedArgString = lib.escapeShellArgs derivedPatterns;

  script = ../../scripts/stignore-merge.py;
  testScript = ../../scripts/test_stignore_merge.py;
in
  pkgs.runCommand "test-stignore-merge" {
    nativeBuildInputs = [pkgs.python3];
    inherit derivedPatterns expectedLineCount;
  } ''
    set -euo pipefail

    # --- Phase 1: unit tests -------------------------------------------------
    cp ${script} ./stignore-merge.py
    cp ${testScript} ./test_stignore_merge.py
    python3 test_stignore_merge.py

    # --- Phase 2: integration with the real derived list ---------------------
    mkdir -p Projects
    printf 'node_modules\n/.artifact\n' > Projects/.stignore

    python3 ./stignore-merge.py ${mergeArgString}

    # The pre-existing lines stay first and unchanged.
    first=$(sed -n '1p' Projects/.stignore)
    second=$(sed -n '2p' Projects/.stignore)
    if [ "$first" != "node_modules" ] || [ "$second" != "/.artifact" ]; then
      echo "pre-existing lines changed or reordered: [$first] [$second]" >&2
      exit 1
    fi

    # The same arguments pass `--check` afterwards.
    python3 ./stignore-merge.py ${mergeArgString} --check

    # No duplicate lines at all.
    duplicates=$(sort Projects/.stignore | uniq -d)
    if [ -n "$duplicates" ]; then
      echo "duplicate .stignore lines:" >&2
      echo "$duplicates" >&2
      exit 1
    fi

    # Exactly the unique expected line set.
    actual=$(wc -l < Projects/.stignore)
    if [ "$actual" -ne ${toString expectedLineCount} ]; then
      echo "expected ${toString expectedLineCount} lines, got $actual" >&2
      cat Projects/.stignore >&2
      exit 1
    fi

    # Every derived pattern appears exactly once.
    for pattern in ${derivedArgString}; do
      count=$(grep -Fx -- "$pattern" Projects/.stignore | wc -l)
      if [ "$count" -ne 1 ]; then
        echo "pattern $pattern appears $count time(s), expected exactly 1" >&2
        exit 1
      fi
    done

    # A second run is byte-identical.
    sha256sum Projects/.stignore > before.sha
    python3 ./stignore-merge.py ${mergeArgString} > /dev/null
    sha256sum -c before.sha

    echo "stignore-merge tests OK (integration: ${toString expectedLineCount} unique lines)" > "$out"
  ''
