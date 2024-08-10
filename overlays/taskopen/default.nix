# No longer need it (have package now instead). But it's a good example anyway.
{
  channels,
  inputs,
  ...
}: final: prev: {
  # inherit (channels.nixpkgs) taskopen;

  # taskopen = inputs.nixpkgs.taskopen.overrideAttrs (old: {
  taskopen = inputs.nixpkgs.legacyPackages.${prev.system}.taskopen.overrideAttrs (old: rec {
    version = "2.0.1";
    src = prev.fetchFromGitHub {
      owner = "jschlatow";
      repo = "taskopen";
      rev = "refs/tags/v${version}";
      hash = "sha256-Gy0QS+FCpg5NGSctVspw+tNiBnBufw28PLqKxnaEV7I=";
    };
    buildInputs =
      with prev; [nim git];
      # ++ (with prev.perlPackages; [JSON perl]);
  });
}
