# Source: https://github.com/NixOS/nixpkgs/pull/297473
{
  fetchFromGitHub,
  buildEnv,
  pkgs,
}: let
  tmuxPlugin = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "harpoon";
    version = "v0.4.0";
    src = fetchFromGitHub {
      owner = "Chaitanyabsprip";
      repo = "tmux-harpoon";
      rev = "fad397d42f04c31874fb7593fb7046d1f8d14864";
      hash = "sha256-eqzf3hEaliF1t7zwZlj1YDGvn0jKdbBTgy5PoOPVMEU=";
    };
  };
in
  # Combine scripts to a single package.
  buildEnv {
    name = "harpoon";
    paths = [tmuxPlugin];
  }
# stdenv.mkDerivation (finalAttrs: rec {
#   pname = "taskopen2";
#   version = "v2.0.1";
#   src = fetchFromGitHub {
#     owner = "jschlatow";
#     repo = "taskopen";
#     rev = "refs/tags/${version}";
#     hash = "sha256-Gy0QS+FCpg5NGSctVspw+tNiBnBufw28PLqKxnaEV7I=";
#   };
#   sourceRoot = "${finalAttrs.src.name}/";
#   postPatch = ''
#     # We don't need a DESTDIR and an empty string results in an absolute path
#     # (due to the trailing slash) which breaks the build.
#     sed 's|$(DESTDIR)/||' -i Makefile
#   '';
#   nativeBuildInputs = [makeWrapper];
#   buildInputs = [nim git];
#   buildPhase = ''
#     export HOME=$(pwd)
#   '';
#   installPhase = ''
#     make PREFIX=$out install
#   '';
#   meta = with lib; {
#     description = "Script for taking notes and open urls with taskwarrior";
#     mainProgram = "taskopen";
#     homepage = "https://github.com/jschlatow/taskopen";
#     platforms = platforms.linux ++ platforms.darwin;
#     license = licenses.gpl2Plus;
#     maintainers = [maintainers.winpat];
#   };
# })
