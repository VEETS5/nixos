{ config, pkgs, ... }:
{
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
        active-color "#719cd6"
        inactive-color "#393b44"
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
    spawn-at-startup "sh" "-c" "sleep 1 && swww img /home/vito/Wallpaper/default.png"
  '';
}
