{ config, pkgs, vitobar, osConfig, ... }:
  let
    vitobarPkg = vitobar.packages.${pkgs.stdenv.hostPlatform.system}.default;
    hostname = osConfig.networking.hostName;
    isDesktop = hostname == "nixtop";
  in
{
  xdg.configFile."niri/config.kdl".text = ''
    prefer-no-csd
    hotkey-overlay {
      skip-at-startup
    }

    input {
      keyboard {
        xkb { layout "us"; }
        repeat-delay 300
        repeat-rate 50
      }
      touchpad {
        tap
        accel-speed 0.2
      }
      focus-follows-mouse
    }

    ${if isDesktop then ''
    output "DP-1" {
      mode "2560x1440@240"
      position x=0 y=0
    }
    output "DP-3" {
      mode "1920x1200@60"
      position x=2560 y=0
    }
    '' else ""}

    layout {
      gaps 5
      preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
      }
      default-column-width { proportion 0.5; }
      focus-ring {
        width 2
        active-color "#${config.lib.stylix.colors.base0D}"
        inactive-color "#${config.lib.stylix.colors.base02}"
      }
      border { off; }
    }

    binds {
      Mod+Return { spawn "foot"; }
      Mod+Space  { spawn "${vitobarPkg}/bin/vitolauncher"; }
      Mod+Q      { close-window; }
      Mod+W      { spawn "firefox"; }
      Mod+E      { spawn "dolphin"; }

      Mod+H { focus-column-left; }
      Mod+L { focus-column-right; }
      ${if isDesktop then ''
      Mod+J { focus-monitor-left; }
      Mod+K { focus-monitor-right; }
      '' else ''
      Mod+J { focus-window-down; }
      Mod+K { focus-window-up; }
      ''}

      Mod+Shift+H { move-column-left; }
      Mod+Shift+L { move-column-right; }
      ${if isDesktop then ''
      Mod+Shift+J { move-column-to-monitor-left; }
      Mod+Shift+K { move-column-to-monitor-right; }
      '' else ""}

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

      Mod+WheelScrollDown cooldown-ms=150 { focus-column-right; }
      Mod+WheelScrollUp   cooldown-ms=150 { focus-column-left; }

      Mod+Backslash { spawn "sh" "-c" "pkill -x vitobar || ${vitobarPkg}/bin/vitobar &"; }

      Mod+Shift+E { quit; }
    }

    window-rule {
      match app-id=r#"^steam_app_"#
      open-fullscreen true
    }

    spawn-at-startup "systemctl" "--user" "start" "niri-session.service"
    spawn-at-startup "mako"
    spawn-at-startup "swww-daemon"
    spawn-at-startup "sh" "-c" "sleep 1 && swww img /home/vito/Wallpaper/default.png"
    spawn-at-startup "${vitobarPkg}/bin/vitobar"
  '';
}
