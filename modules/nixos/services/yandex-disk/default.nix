{
  lib,
  namespace,
  config,
  ...
}:
lib.${namespace}.mkIfEnabled {
  inherit config;
  category = "services";
  name = "yandex-disk";
}
{
  services.yandex-disk = {
    enable = true;

    # FIX: Issues:
    # 1. User should own secret files
    # 2. You should get token on site after using `token` command. It's better
    # to deploy from sops directly. According to help it's `~/.config/yandex-disk/passwd`
    # so maybe we even can hash it via passwd.
    # 3. Even after having token in the right folder it's not working. Maybe
    # just a path issue. We have token in a `services.yandex-disk.directory`
    # but token command in service has `/var/lib/yandex-disk/token` at the end.
    # I've run command with the same argument but to avail.
    # 4. According to `journalctl` service is failing because of 2nd point
    # timeout. Maybe it will be fixed once it finds a token but I'm not sure.
    user = "root";

    username = /*bash*/ ''"$(cat ${config.sops.secrets."yandex_disk_username".path})"'';
    password = /*bash*/ ''"$(cat ${config.sops.secrets."yandex_disk_password".path})"'';

    directory = "/shared/data/YandexDisk";
  };
}
