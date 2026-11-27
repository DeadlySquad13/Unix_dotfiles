{
  pkgs,
  ...
}:
# Runs the stdlib-only comparison tests for the live Syncthing ignore check in
# the Nix sandbox. The suite is offline by design: it exercises the pure
# comparison functions, the alias expansion, and `--payload-file` loading. The
# live `/rest/db/ignores` call is made only by the Makefile target on a host
# where Syncthing is running.
pkgs.runCommand "test-stignore-syncthing-e2e" {
  nativeBuildInputs = [pkgs.python3];
} ''
  cp ${../../scripts/stignore-syncthing-e2e.py} \
    ./stignore-syncthing-e2e.py
  cp ${../../scripts/test_stignore_syncthing_e2e.py} \
    ./test_stignore_syncthing_e2e.py
  python3 test_stignore_syncthing_e2e.py
  echo "stignore-syncthing-e2e tests OK" > "$out"
''
