{ config, pkgs, ... }:
{
  home.packages = [ pkgs.macchina ];

  xdg.configFile."macchina/macchina.toml".text = ''
    [palette]
    visible = false

    [keys]
    host = "Host"
    kernel = "Kernel"
    os = "OS"
    packages = "Packages"
    uptime = "Uptime"
    shell = "Shell"
    terminal = "Terminal"
    cpu = "CPU"
    memory = "Memory"

    [theme]
    separator = " => "
    separator_color = "Blue"
    key_color = "Blue"

    [ascii]
    path = "${config.home.homeDirectory}/.config/macchina/nixos.ascii"
  '';

  xdg.configFile."macchina/nixos.ans".source = ../../assets/nixos.ans;
}
