{ config, pkgs, osConfig, ... }:
  let
    noctalia = "${config.programs.noctalia.package}/bin/noctalia";
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
        // drag-lock = the sticky tap-and-drag: once a drag/hold starts, a brief
        // lift won't end it — you tap once to release. (drag-lock requires drag.)
        drag true
        drag-lock
        accel-speed 0.2
      }
      focus-follows-mouse max-scroll-amount="0%"
    }

    ${if isDesktop then ''
    output "DP-1" {
      mode "2560x1440@240"
      position x=0 y=0
    }
    output "DP-3" {
      mode "1920x1200@99.997"
      position x=2560 y=0
    }
    '' else ''
    output "eDP-1" {
      mode "2880x1800@120"
    }
    ''}

    gestures {
      hot-corners {
        off
      }
    }

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
      Mod+Space  { spawn "${noctalia}" "msg" "panel-toggle" "launcher"; }
      Mod+Q      { close-window; }
      Mod+W      { spawn "firefox"; }
      Mod+E      { spawn "dolphin"; }
      Mod+P      { spawn "spotify"; }
      Mod+S      { spawn "steam"; }
      Mod+V      { spawn "vesktop"; }
      Mod+C      { spawn "code"; }

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

      Print       { spawn "sh" "-c" "grim - | satty -f - --output-filename ~/Pictures/screenshot-$(date +%s).png --copy-command wl-copy"; }
      Mod+Shift+S { spawn "sh" "-c" "grim -g \"$(slurp)\" - | satty -f - --output-filename ~/Pictures/screenshot-$(date +%s).png --copy-command wl-copy"; }

      XF86AudioRaiseVolume  { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
      XF86AudioLowerVolume  { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
      XF86AudioMute         { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
      XF86AudioPlay { spawn "playerctl" "play-pause"; }
      XF86AudioNext { spawn "playerctl" "next"; }
      XF86AudioPrev { spawn "playerctl" "previous"; }
      XF86MonBrightnessUp   { spawn "brightnessctl" "set" "5%+"; }
      XF86MonBrightnessDown { spawn "brightnessctl" "set" "5%-"; }

      Mod+WheelScrollDown cooldown-ms=150 { focus-column-right; }
      Mod+WheelScrollUp   cooldown-ms=150 { focus-column-left; }

      Mod+Backslash { spawn "${noctalia}" "msg" "bar-toggle"; }
      Mod+Comma { spawn "${noctalia}" "msg" "settings-toggle"; }
      Mod+Shift+Comma { spawn "${noctalia}" "msg" "panel-toggle" "control-center"; }

      Mod+Shift+E { quit; }
    }

    window-rule {
      match app-id="dev.noctalia.Noctalia"
      open-floating true
    }

    window-rule {
      match app-id=r#"^steam_app_"#
      open-fullscreen true
    }

    window-rule {
      match app-id=r#"^gamescope$"#
      match app-id=r#"^\.gamescope-wrapped$"#
      open-fullscreen true
    }

    spawn-at-startup "copyq" "--start-server"
    // Runs headless if no tray host is present — it is still the bluez pairing
    // agent (PIN/confirm dialogs) and drives auto-reconnect for known devices.
    spawn-at-startup "${pkgs.blueman}/bin/blueman-applet"
  '';
}
