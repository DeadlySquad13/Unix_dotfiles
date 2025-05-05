# Systems
Like with `homes` there's a configuration for modules. While structure of this
config is very similar they both controlled by different attrsets. While both
`home` and `system` use the same function `mkIfEnabled`, it accepts argument
`config` which is different depending on where module is defined. If it's
in `modules/nixos`, it will accept `config` from system, otherwise - from home.
