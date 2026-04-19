{ pkgs, lib, osConfig, ... }:

let
  isLaptop = osConfig.networking.hostName == "nixpad";

  oled-refresh = pkgs.python3Packages.buildPythonApplication {
    pname = "oled-refresh";
    version = "1.0";
    format = "other";

    nativeBuildInputs = [ pkgs.wrapGAppsHook4 pkgs.gobject-introspection ];
    buildInputs = [ pkgs.gtk4 ];
    propagatedBuildInputs = [ pkgs.python3Packages.pygobject3 ];

    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      mkdir -p $out/bin
      cat > $out/bin/oled-refresh <<'PYEOF'
#!/usr/bin/env python3
import gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, GLib, Gdk

COLORS = [
    (1, 1, 1),
    (1, 0, 0),
    (0, 1, 0),
    (0, 0, 1),
    (0, 1, 1),
    (1, 0, 1),
    (1, 1, 0),
    (0, 0, 0),
]

class RefreshWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app)
        self.color_index = 0
        self.fullscreen()
        self.set_cursor(Gdk.Cursor.new_from_name("none"))
        self.canvas = Gtk.DrawingArea()
        self.canvas.set_draw_func(self.on_draw)
        self.set_child(self.canvas)
        GLib.timeout_add(2000, self.next_color)

    def on_draw(self, area, cr, width, height):
        r, g, b = COLORS[self.color_index]
        cr.set_source_rgb(r, g, b)
        cr.paint()

    def next_color(self):
        self.color_index += 1
        if self.color_index >= len(COLORS):
            self.get_application().quit()
            return False
        self.canvas.queue_draw()
        return True

def on_activate(app):
    win = RefreshWindow(app)
    win.present()

app = Gtk.Application(application_id="com.vito.oled-refresh")
app.connect("activate", on_activate)
app.run()
PYEOF
      chmod +x $out/bin/oled-refresh
    '';

    dontWrapGApps = false;
    preFixup = ''
      makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
    '';
  };
in
lib.mkIf isLaptop {
  systemd.user.services.oled-refresh = {
    Unit = {
      Description = "OLED pixel refresh cycle";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${oled-refresh}/bin/oled-refresh";
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
