{ inputs, pkgs, lib, ... }:
{
  imports = [ inputs."minegrub-theme".nixosModules.default ];

  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    useOSProber = true;
    minegrub-theme = {
      enable = true;
      background = "background_options/1.16 - [Nether Update].png";
      boot-options-count = 4;
    };
  };
}
