{ config, pkgs, ... }:
{
  home.packages = [ pkgs.macchina ];

  xdg.configFile."macchina/themes/nixos.toml".text = ''
    [ascii]
    path = "/home/vito/.config/macchina/nixos.ans"
  '';

  xdg.configFile."macchina/nixos.ans".text = builtins.readFile ../assets/nixos.ans;
}
