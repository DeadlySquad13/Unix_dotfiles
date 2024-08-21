{ lib, ...}: lib.mkIf false {
  services.picom = {
    enable = true;
    # Tried to fix flickering
    # [Nvidia NixOs wiki][@NvidiaNixOSWiki]|[Zotero][z@NvidiaNixOSWiki].
    # [Picom Arch wiki][@PicomArchWiki]|[Zotero][z@PicomArchWiki]
    vSync = true;
    settings = {
      unredir-if-possible = false;
    };
  };
}

/* References:
[@NvidiaNixOSWiki]: <https://nixos.wiki/wiki/Nvidia#Using_GPUs_on_non-NixOS> 'Nvidia - NixOS Wiki'
[z@NvidiaNixOSWiki]: <zotero://select/items/@NvidiaNixOSWiki> 'Select in Zotero: Nvidia - NixOS Wiki'
[@PicomArchWiki]: <https://wiki.archlinux.org/title/Picom#Configuration> 'Picom - ArchWiki'
[z@PicomArchWiki]: <zotero://select/items/@PicomArchWiki> 'Select in Zotero: Picom - ArchWiki'
*/
