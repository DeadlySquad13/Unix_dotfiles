{
  disko.devices = {
    disk = {
      nvme = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              label = "esp";
              size = "546M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            swap = {
              label = "swap";
              size = "36G";
              content = {
                type = "swap";
                discardPolicy = "both";
                resumeDevice = true; # Resume from hibernation from this device.

                # Encryption.
                randomEncryption = true;
                priority = 100; # Prefer to encrypt as long as we have space for it.
              };
            };
            home = {
              label = "home";
              size = "50G";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/home";
              };
            };
            # TODO: Add options for ashift and so on.
            shared = {
              label = "shared";
              size = "160G";
              content = {
                type = "zfs";
                pool = "zshared";
              };
            };
            var = {
              label = "var";
              size = "147G";
              content = {
                type = "zfs";
                pool = "zcake";
              };
            };
            root = {
              label = "root";
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
    };
    zpool = {
      zshared = {
        type = "zpool";
        rootFsOptions = {
          # These are inherited to all child datasets as the default value.
          compression = "lz4";
          ashift = "12";
          xattr = "sa";
          atime = "off";
          recordsize = "64K";
          "com.sun:auto-snapshot" = "false";
        };
        mountpoint = "/shared";
        postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^zshared@blank$' || zfs snapshot zshared@blank";

        datasets = {
          "configs_scripts" = {
            type = "zfs_fs";
            mountpoint = "/shared/_configs!scripts";
          };
          "projects" = {
            type = "zfs_fs";
            mountpoint = "/shared/Projects";
          };
          "data" = {
            type = "zfs_fs";
            mountpoint = "/shared/data";
            options = {
              # data is mostly big binary files like images or pdfs.
              recordsize = "1M";
            };
          };
        };
      };
      # Has separated local and shared datasets. Shared dataset is different from zshared in
      # nature (and in requirements): it doesn't just store shared data but
      # actively uses it (mainly variable data, cache files...) so fs settings
      # are different.
      zcake = {
        type = "zpool";
        rootFsOptions = {
          compression = "lz4";
          "com.sun:auto-snapshot" = "false";
          ashift = "12";
          xattr = "sa";
          atime = "off";
          recordsize = "64K";
        };
        mountpoint = "/zcake";
        postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^zcake@blank$' || zfs snapshot zcake@blank";

        # QUESTION: How to make multiple mountpoints? Maybe posthook?
        # QUESTION: How to mount to home when it's not yet created?
        datasets = {
          "local-" = {
            type = "zfs_fs";
            mountpoint = "/zsalt/local-";
            options."com.sun:auto-snapshot" = "true";
          };
          "shared-" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
          "local-/nix" = {
            type = "zfs_fs";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/nix";
            };
          };
          "local-/var-" = {
            type = "zfs_fs";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/var";
            };
          };
          "local-/var-/cache" = {
            type = "zfs_fs";
            content = {
              type = "filesystem";
              format = "ext4";
              # TODO: Also mount to home dir.
              mountpoint = "/zsalt/local-/var-/cache";
            };
          };
          "local-/var-/share" = {
            type = "zfs_fs";
            content = {
              type = "filesystem";
              format = "ext4";
              # TODO: Also mount to home dir.
              mountpoint = "/zsalt/local-/var-/share";
            };
          };
        };
      };
      zroot = {
        type = "zpool";
        rootFsOptions = {
          compression = "lz4";
          "com.sun:auto-snapshot" = "true";
          ashift = "12";
          xattr = "sa";
          atime = "off";
          recordsize = "64K";
        };
        mountpoint = "/";
        postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^zroot@blank$' || zfs snapshot zroot@blank";

        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
