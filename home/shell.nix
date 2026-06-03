{ config, pkgs, ... }:
{
  programs.bash = {
    enable = true;
    shellAliases = {
      nrl = "sudo nixos-rebuild switch --flake ~/.config/nixos#nixpad";
      nrd = "sudo nixos-rebuild switch --flake ~/.config/nixos#nixtop";
      ll   = "ls -la";
      cls  = "clear";
      snvim = "sudo -E nvim";
      ni = "cd ~/.config/nixos/";
      vbu = "bash ~/.config/nixos/update-vitobar.sh";
      ncp = "cd ~/.config/nixos && git add -A && git commit -m \"update config\" && git push && cd -";
      claude-latest = "$HOME/.local/bin/claude";
    };
    initExtra = ''
      export EDITOR=nvim
      macchina --theme nixos
    '';
  };
}
