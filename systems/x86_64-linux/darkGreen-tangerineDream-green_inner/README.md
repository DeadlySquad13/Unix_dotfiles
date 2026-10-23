# tangerineDream-green inner
This system is intended to be used inside `darkGreen-tangerineDream-green` docker
container. These systems shared the same name before `Nix ~= 2.24` but after
update their names began conflicting. Apart from that they even have the same
hostname, hence home-manager module is still associated with
`tangerineDream-green`. Even though it's actually applied at
`darkGreen-tangerineDream-green_inner`.

This is the green twin of `darkGreen-tangerineDream_inner` and the in-container
switch target of the agent child-flake model (see ADR 0003, ADR 0006, ADR 0007).
It is switched inside the running container with
`make switch-darkGreen-tangerineDream-green-system`
(`sudo nixos-rebuild switch --flake .#darkGreen-tangerineDream-green_inner --impure`);
it is **not** rebuilt into the outer image.

> See `Deploy#NixContainer.puml` at InfoField for better understading.
