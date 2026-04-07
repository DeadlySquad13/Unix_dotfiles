{
  channels,
  inputs,
  ...
}: final: prev: {
  ds-omega-aider-chat = inputs.nixpkgs.legacyPackages.${prev.system}.aider-chat.withOptional {
    withBrowser = true;
    # TODO: Issues with spacy installation, update nixpkgs to 26.0.0
    # See: https://github.com/NixOS/nixpkgs/pull/466482
    withHelp = false;
    withPlaywright = true;
    withBedrock = false; # Not used.
  };
}
