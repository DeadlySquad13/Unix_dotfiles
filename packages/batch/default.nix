{
  lib,
  stdenv,
  crystal,
  shards,
  llvm,
  git,
  nim,
  mandoc,
  fetchFromGitHub,
  makeWrapper,
  ...
}:
stdenv.mkDerivation (finalAttrs: rec {
  pname = "batch";
  version = "nightly";

  src = fetchFromGitHub {
    owner = "taupiqueur";
    repo = "batch";
    rev = "refs/tags/${version}";
    hash = "sha256-/So4Oz+e1E1hfY6mprIOk3+LNSMwc9lMQBvC63K3PJg=";
  };

  sourceRoot = "${finalAttrs.src.name}/";

  nativeBuildInputs = [
    crystal
    shards
    llvm
    git
    mandoc
    nim
    makeWrapper
  ];

  # Set HOME to a writable directory in the build sandbox
  preBuild = ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME/.cache/crystal"
  '';

  # Pass any additional Crystal compiler flags
  CRYSTAL_CACHE_DIR = "$HOME/.cache/crystal";

  # # Debug: list files after build
  # buildPhase = ''
  #   runHook preBuild
  #   # shards build --release
  #   echo "=== Contents of bin/ after build ==="
  #   ls -la /test
  #   runHook postBuild
  # '';

  makeFlags = [
    "PREFIX=$(out)"
  ];

  # Optional: Disable git check if you don't need git info in the build
  preConfigure = ''
    # If your build uses git for version info, you might need this
    export GIT_DIR="''${src}/.git"
  '';

  meta = with lib; {
    description = "A tool for batch processing using your favorite text editor.";
    mainProgram = "batch";
    homepage = "https://github.com/taupiqueur/batch";
    platforms = platforms.linux ++ platforms.darwin;
    license = licenses.gpl2Plus;
    maintainers = [maintainers.winpat];
  };
})
