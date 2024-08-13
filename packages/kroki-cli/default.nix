{
  lib,
  fetchFromGitHub,
  buildGoModule,
}:
buildGoModule rec {
  pname = "kroki-cli";

  version = "v0.5.0";

  src = fetchFromGitHub {
    owner = "yuzutech";
    repo = "kroki-cli";
    rev = "refs/tags/${version}";
    hash = "sha256-KdP06tNeXPOyQB8gRYcxABHrjgzKtmxz2VudpjsofYE=";
  };

  vendorHash = "sha256-HqiNdNpNuFBfwmp2s0gsa2YVf3o0O2ILMQWfKf1Mfaw=";

  meta = with lib; {
    description = "A Kroki CLI: create diagrams from textual descriptions";
    mainProgram = "kroki";
    homepage = "https://github.com/yuzutech/kroki-cli";
    platforms = platforms.linux ++ platforms.darwin;
    license = licenses.mit;
    # maintainers = [maintainers.DeadlySquad13];
  };
}
