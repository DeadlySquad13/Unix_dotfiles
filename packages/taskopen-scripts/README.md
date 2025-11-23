# Taskopen Scripts

My personal scripts for taskopen. Included directly into taskopen config by using Nix string
interpolation capabilites. Code is based on builtin scripts that are distributed
alongside repository.

For reference see builtin scripts at [repository](https://github.com/jschlatow/taskopen/tree/495dfb2e54716ba8940c1a1688ac26da025c5a2f/scripts).
They're available for use in the config too because of `path_ext` option
(extends `PATH` of the taskopen scripts).

Or look them up at the nix store:

```bash
which taskopen # get a path before `/bin/taskopen`
cd <taskopenRootPath>/share/taskopen/scripts/
```

## Naming

Use the same name as the builtin script if you intend on overwriting it.
Otherwise just follow regular conventions.
