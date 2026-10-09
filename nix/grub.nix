{ inputs, pkgs, lib, ... }:
{
  imports = [ inputs."minegrub-theme".nixosModules.default ];

  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = true;
    useOSProber = true;
    configurationLimit = 10;
    extraInstallCommands = ''
      # Keep the existing firmware entry synchronized with removable GRUB.
      mkdir -p /boot/EFI/NixOS-boot
      cp /boot/EFI/BOOT/BOOTX64.EFI /boot/EFI/NixOS-boot/grubx64.efi
    '';
    minegrub-theme = {
      enable = true;
      background = "background_options/1.16 - [Nether Update].png";
      boot-options-count = 4;
    };
  };
}
