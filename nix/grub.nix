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
    extraInstallCommands = ''
      # Clean up leftover systemd-boot files from the installer
      rm -rf /boot/EFI/systemd /boot/EFI/Linux /boot/loader/entries /boot/loader/loader.conf 2>/dev/null || true
    '';
    minegrub-theme = {
      enable = true;
      background = "background_options/1.16 - [Nether Update].png";
      boot-options-count = 4;
    };
  };
}
