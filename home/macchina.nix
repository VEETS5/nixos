{ config, pkgs, ... }:
{
  home.packages = [ pkgs.macchina ];

  xdg.configFile."macchina/macchina.toml".text = ''
    [theme]
    name = "nixos"
  '';

  xdg.configFile."macchina/themes/nixos.toml".text = ''
    [separator]
    glyph = " => "

    [bar]
    glyph = "▪"

    [keys]
    host = "Host"
    kernel = "Kernel"
    distro = "Distro"
    packages = "Packages"
    uptime = "Uptime"
    shell = "Shell"
    terminal = "Terminal"
    cpu = "CPU"
    memory = "Memory"
    battery = "Battery"

    [ascii]
    path = "${config.home.homeDirectory}/.config/macchina/nixos.ans"
  '';

  xdg.configFile."macchina/nixos.ans".text = builtins.readFile ../assets/nixos.ans;
}
