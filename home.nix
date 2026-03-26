{ config, pkgs, ... }:
{
  home.username      = "vito";
  home.homeDirectory = "/home/vito";
  home.stateVersion  = "25.11";

  home.packages = with pkgs; [
    firefox
    fuzzel
    mako
    swww
    grim
    slurp
    btop
    ripgrep
    fd
    gh
    vim
    neovim
  ];

  # ── Shell ───────────────────────────────────────────────────────────────────
  programs.bash = {
    enable = true;
    shellAliases = {
      nrl = "sudo nixos-rebuild switch --flake /etc/nixos#nixpad";
      nrd = "sudo nixos-rebuild switch --flake /etc/nixos#nixtop";
    };
  };

  # ── Foot ────────────────────────────────────────────────────────────────────
  programs.foot = {
    enable = true;
    settings = {
      main = {
        term      = "xterm-256color";
        font      = "JetBrainsMono Nerd Font:size=10";
        dpi-aware = "yes";
      };
      colors-dark = {
        background = "1e1e2e";
        foreground = "cdd6f4";
        regular0 = "45475a"; regular1 = "f38ba8";
        regular2 = "a6e3a1"; regular3 = "f9e2af";
        regular4 = "89b4fa"; regular5 = "f5c2e7";
        regular6 = "94e2d5"; regular7 = "bac2de";
        bright0  = "585b70"; bright1  = "f38ba8";
        bright2  = "a6e3a1"; bright3  = "f9e2af";
        bright4  = "89b4fa"; bright5  = "f5c2e7";
        bright6  = "94e2d5"; bright7  = "a6adc8";
      };
      cursor     = { style = "beam"; blink = "yes"; };
      scrollback = { lines = 10000; };
    };
  };

  # ── Niri ────────────────────────────────────────────────────────────────────
  xdg.configFile."niri/config.kdl".text = ''
    prefer-no-csd

    input {
      keyboard {
        xkb { layout "us"; }
        repeat-delay 300
        repeat-rate 50
      }
      touchpad {
        tap
        natural-scroll
        accel-speed 0.2
      }
    }

    layout {
      gaps 10
      preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
      }
      default-column-width { proportion 0.5; }
      focus-ring {
        width 2
        active-color "#89b4fa"
        inactive-color "#45475a"
      }
      border { off; }
    }

    binds {
      Mod+Return { spawn "foot"; }
      Mod+Space  { spawn "fuzzel"; }
      Mod+Q      { close-window; }

      Mod+H { focus-column-left; }
      Mod+L { focus-column-right; }
      Mod+J { focus-window-down; }
      Mod+K { focus-window-up; }

      Mod+Shift+H { move-column-left; }
      Mod+Shift+L { move-column-right; }

      Mod+1 { focus-workspace 1; }
      Mod+2 { focus-workspace 2; }
      Mod+3 { focus-workspace 3; }
      Mod+4 { focus-workspace 4; }
      Mod+5 { focus-workspace 5; }

      Mod+Shift+1 { move-window-to-workspace 1; }
      Mod+Shift+2 { move-window-to-workspace 2; }
      Mod+Shift+3 { move-window-to-workspace 3; }
      Mod+Shift+4 { move-window-to-workspace 4; }
      Mod+Shift+5 { move-window-to-workspace 5; }

      Mod+R       { switch-preset-column-width; }
      Mod+F       { maximize-column; }
      Mod+Shift+F { fullscreen-window; }
      Mod+Minus   { set-column-width "-10%"; }
      Mod+Equal   { set-column-width "+10%"; }

      Print       { screenshot; }
      Mod+Shift+S { screenshot-window; }

      XF86AudioRaiseVolume  { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
      XF86AudioLowerVolume  { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
      XF86AudioMute         { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
      XF86MonBrightnessUp   { spawn "brightnessctl" "set" "5%+"; }
      XF86MonBrightnessDown { spawn "brightnessctl" "set" "5%-"; }

      Mod+Shift+E { quit; }
    }

    spawn-at-startup "mako"
    spawn-at-startup "swww-daemon"
  '';

  # ── Mako ────────────────────────────────────────────────────────────────────
  services.mako = {
    enable = true;
    settings = {
      default-timeout  = 5000;
      background-color = "#1e1e2e";
      text-color       = "#cdd6f4";
      border-color     = "#89b4fa";
      border-radius    = 8;
      border-size      = 2;
      font             = "JetBrainsMono Nerd Font 10";
    };
  };

  programs.home-manager.enable = true;
}
