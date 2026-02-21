# Source: https://github.com/NixOS/nixpkgs/pull/297473
{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  nim,
  git,
  ...
}:
stdenv.mkDerivation (finalAttrs: rec {
  pname = "taskopen2";

  version = "v2.0.1";

  src = fetchFromGitHub {
    owner = "jschlatow";
    repo = "taskopen";
    rev = "refs/tags/${version}";
    hash = "sha256-Gy0QS+FCpg5NGSctVspw+tNiBnBufw28PLqKxnaEV7I=";
  };

  sourceRoot = "${finalAttrs.src.name}/";

  postPatch = ''
    # We don't need a DESTDIR and an empty string results in an absolute path
    # (due to the trailing slash) which breaks the build.
    sed 's|$(DESTDIR)/||' -i Makefile
  '';

  nativeBuildInputs = [makeWrapper];
  buildInputs = [
    nim
    git
  ];


  # Set HOME to a writable directory in the build sandbox
  preBuild = ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME/.cache/crystal"
  '';

  # Pass any additional Crystal compiler flags
  CRYSTAL_CACHE_DIR = "$HOME/.cache/crystal";

  installPhase = ''
    make PREFIX=$out install
  '';

  meta = with lib; {
    description = "Script for taking notes and open urls with taskwarrior";
    mainProgram = "taskopen";
    homepage = "https://github.com/jschlatow/taskopen";
    platforms = platforms.linux ++ platforms.darwin;
    license = licenses.gpl2Plus;
    maintainers = [maintainers.winpat];
  };
})
