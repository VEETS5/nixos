{ config, pkgs, lib, ... }:
{
  home.packages = [ pkgs.foot ];
  xdg.configFile."foot/foot.ini".force = true;
  xdg.configFile."foot/foot.ini".text = ''
    [main]
    term=xterm-256color
    font=JetBrainsMono Nerd Font:size=11
    dpi-aware=no

    [scrollback]
    lines=10000

    [cursor]
    style=beam
    blink=yes

    [colors-dark]
    alpha=1.0
    background=${config.lib.stylix.colors.base00}
    foreground=${config.lib.stylix.colors.base05}
    regular0=${config.lib.stylix.colors.base00}
    regular1=${config.lib.stylix.colors.base08}
    regular2=${config.lib.stylix.colors.base0B}
    regular3=${config.lib.stylix.colors.base0A}
    regular4=${config.lib.stylix.colors.base0D}
    regular5=${config.lib.stylix.colors.base0E}
    regular6=${config.lib.stylix.colors.base0C}
    regular7=${config.lib.stylix.colors.base05}
    bright0=${config.lib.stylix.colors.base03}
    bright1=${config.lib.stylix.colors.base08}
    bright2=${config.lib.stylix.colors.base0B}
    bright3=${config.lib.stylix.colors.base0A}
    bright4=${config.lib.stylix.colors.base0D}
    bright5=${config.lib.stylix.colors.base0E}
    bright6=${config.lib.stylix.colors.base0C}
    bright7=${config.lib.stylix.colors.base07}
  '';
}
