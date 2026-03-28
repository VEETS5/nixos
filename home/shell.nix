{ config, pkgs, ... }:
{
  programs.bash = {
    enable = true;
    shellAliases = {
      nrl = "sudo nixos-rebuild switch --flake /etc/nixos#nixpad";
      nrd = "sudo nixos-rebuild switch --flake /etc/nixos#nixtop";
      ll   = "ls -la";
      cls  = "clear";
      snvim = "sudo -E nvim";
    };
    initExtra = ''
      export EDITOR=nvim
      macchina --theme nixos
    '';
  };
}
