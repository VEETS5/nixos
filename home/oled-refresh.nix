{ pkgs, lib, osConfig, ... }:

let
  isLaptop = osConfig.networking.hostName == "nixpad";

  oled-refresh = pkgs.writeShellScript "oled-refresh" ''
    # OLED pixel refresh — cycle solid colors to exercise all subpixels
    WALLPAPER="$HOME/Wallpaper/default.png"

    # Ensure awww daemon is running
    ${pkgs.awww}/bin/awww query > /dev/null 2>&1 || exit 0

    for color in FFFFFF FF0000 00FF00 0000FF 000000; do
      ${pkgs.awww}/bin/awww clear "$color" --transition-type none
      sleep 2
    done

    # Restore wallpaper
    ${pkgs.awww}/bin/awww img "$WALLPAPER" --transition-type none
  '';
in
lib.mkIf isLaptop {
  systemd.user.services.oled-refresh = {
    Unit = {
      Description = "OLED pixel refresh cycle";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${oled-refresh}";
    };
  };

  systemd.user.timers.oled-refresh = {
    Unit.Description = "Run OLED pixel refresh every hour";
    Timer = {
      OnCalendar = "hourly";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
