{ config, pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    foot
    # ── Terminal image viewers (sixel) ────────────────────────────────────────
    # foot has no kitty/iTerm graphics protocol — sixel is the one it speaks.
    chafa    # general-purpose; auto-picks sixel from TERM, `-f sixel` forces it
    libsixel # img2sixel: straight PNG/JPG -> sixel, plus sixel2png the other way
    timg     # images, animated GIFs and video frames, sixel-capable
  ];

  xdg.configFile."foot/foot.ini".force = true;
  xdg.configFile."foot/foot.ini".text = ''
    [main]
    # Must be `foot`, NOT xterm-256color: image viewers decide whether to emit
    # sixel by looking up TERM, and the xterm-256color entry advertises no sixel
    # support, so chafa/timg/spotify-player silently fall back to ANSI blocks.
    # The `foot` entry ships in ncurses itself, so it also resolves under sudo.
    # Remote hosts often lack it — see the ssh wrapper in shell.nix.
    term=foot
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

    [tweak]
    # Already the default in foot 1.27 — pinned explicitly so a future upstream
    # default flip can't silently kill image output.
    sixel=yes
  '';
}
