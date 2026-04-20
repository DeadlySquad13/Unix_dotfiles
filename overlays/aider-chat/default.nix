{
  channels,
  inputs,
  ...
}: final: prev: (
  let
    inherit (inputs.nixpkgs.legacyPackages.${prev.system}) aider-chat;
  in {
    ds-omega-aider-chat =
      (aider-chat.withOptional {
        withBrowser = true;
        # TODO: Issues with spacy installation, update nixpkgs to 26.0.0
        # See: https://github.com/NixOS/nixpkgs/pull/466482
        withHelp = false;
        withPlaywright = true;
        withBedrock = false; # Not used.
      }).overridePythonAttrs
      (old: {
        # As of 0.86.1 some tests related to `max_input_tokens` are impure and require network connection.
        # We could use `--impure --sandbox false` but I decided to ditch it.
        doCheck = false;
      });
  }
)
