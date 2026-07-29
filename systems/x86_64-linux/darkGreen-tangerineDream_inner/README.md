# tangerineDream inner
This system is intended to be used inside `tangerineDream` docker container.
These systems shared the same name before `Nix ~= 2.24` but after update their
names began conflicting. Apart from that they even have the same hostname, hence home-manager
module is still associated with `tangerineDream`. Even though it's actually applied at `tangerineDream_inner`.

> See `Deploy#NixContainer.puml` at InfoField for better understading.
