{ config, pkgs, ... }:
{
  home.packages = [ pkgs.macchina ];

  xdg.configFile."macchina/themes/nixos.toml".text = ''
    [custom_ascii]
    path = "/home/vito/.config/macchina/nixos.ans"
  '';

  xdg.configFile."macchina/nixos.ans".source = ../assets/nixos.ans;
}
