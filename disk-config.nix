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
        # These options inherited to all child datasets as the default value.
        # Fine-tuned according to guide: zotero://select/library/items/KL7JXZFH = https://jrs-s.net/2018/08/17/zfs-tuning-cheat-sheet/

        # - `-o` - pool properties or feature, see zpoolprops and zpool-features man pages respectively.
        options = {
          ashift = "12";
        };

        # - `-O` - filesystem properties, see zfsprops man page.
        rootFsOptions = {
          compression = "lz4";
          xattr = "sa";
          atime = "off";
          recordsize = "64K";
          "com.sun:auto-snapshot" = "false";
        };
        postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^zshared@blank$' || zfs snapshot zshared@blank";

        datasets = {
          # Root relative to this pool. May be needed for other files that
          # don't fit into structure defined below.
          "root" = {
            type = "zfs_fs";
            options.mountpoint = "/shared";
          };
          "configs_scripts" = {
            type = "zfs_fs";
            options.mountpoint = "/shared/_configs!scripts";
          };
          "projects" = {
            type = "zfs_fs";
            options.mountpoint = "/shared/Projects";
          };
          "data" = {
            type = "zfs_fs";
            options.mountpoint = "/shared/data";
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

        options = {
          ashift = "12";
        };

        rootFsOptions = {
          compression = "lz4";
          "com.sun:auto-snapshot" = "false";
          xattr = "sa";
          atime = "off";
          recordsize = "64K";
        };
        postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^zcake@blank$' || zfs snapshot zcake@blank";

        # QUESTION: How to make multiple mountpoints? Maybe posthook?
        # QUESTION: How to mount to home when it's not yet created?
        datasets = {
          "local-" = {
            type = "zfs_fs";
            options = {
              mountpoint = "/zsalt/local-";
              "com.sun:auto-snapshot" = "true";
            };
          };
          "shared-" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
          "local-/nix" = {
            type = "zfs_fs";
            options.mountpoint = "/nix";
          };
          "local-/var-" = {
            type = "zfs_fs";
            options.mountpoint = "/var";
          };
          "local-/var-/cache" = {
            type = "zfs_fs";
            # TODO: Also mount to home dir.
            options.mountpoint = "/zsalt/local-/var-/cache";
          };
          "local-/var-/share" = {
            type = "zfs_fs";
            # TODO: Also mount to home dir.
            options.mountpoint = "/zsalt/local-/var-/share";
          };
        };
      };
      zroot = {
        type = "zpool";

        options = {
          ashift = "12";
        };

        rootFsOptions = {
          compression = "lz4";
          "com.sun:auto-snapshot" = "true";
          xattr = "sa";
          atime = "off";
          recordsize = "64K";
        };
        postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^zroot@blank$' || zfs snapshot zroot@blank";

        datasets = {
          ephemeral = {
            type = "zfs_fs";
            options.mountpoint = "/";
          };
        };
      };
    };
  };
}
