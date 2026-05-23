# FIX: flake attribute 'checks.x86_64-linux._type' is not a derivation
# Test using: nix build --impure .#checks.x86_64-linux.typenix --print-build-logs
{pkgs, inputs, ...}:
pkgs.runCommand "typenix"
{
  nativeBuildInputs = [pkgs.typenix];
}
''
  echo "Running type checks..."
  cd ${inputs.self} && typenix
  touch $out
''
