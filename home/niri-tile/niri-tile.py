"""niri-tile: a non-scrolling "master + stack" layout on top of niri.

niri only has a scrolling layout. In "tile" mode this daemon watches niri's
event stream and keeps every workspace arranged like Hyprland's default with
three windows: the first window on the left half, every other window stacked
in a single column on the right half, so nothing ever scrolls off screen.
"scroll" mode leaves niri alone (one window per column, 50% wide).

  niri-tile daemon             run the layout daemon (systemd user service)
  niri-tile set tile|scroll    switch mode
  niri-tile toggle
  niri-tile get                print the current mode
  niri-tile watch              print the mode now and on every change
"""

import json
import os
import select
import socket
import sys
import time

MODES = ("tile", "scroll")
DEFAULT = os.environ.get("NIRI_TILE_DEFAULT", "tile")
STATE_DIR = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "niri-tile")
MODE_FILE = os.path.join(STATE_DIR, "mode")
# niri `include`s this file; set by the Nix module.
ANIM_FILE = os.environ.get("NIRI_TILE_ANIMATIONS")
# Workspaces holding one of these are left alone (fullscreen games, the
# hourly OLED pixel refresh): resizing a fullscreen window un-fullscreens it.
SKIP_APPS = ("steam_app_", "gamescope", ".gamescope-wrapped",
             "com.vito.oled-refresh")
# Events that can change which windows exist or where they sit. Arranging is
# idempotent, so the layout events our own resizes cause settle immediately.
EVENTS = ("WindowOpenedOrChanged", "WindowClosed", "WindowsChanged",
          "WindowLayoutsChanged", "WorkspaceActivated", "WorkspacesChanged")


def get_mode():
    try:
        with open(MODE_FILE) as f:
            mode = f.read().strip()
        if mode in MODES:
            return mode
    except OSError:
        pass
    return DEFAULT if DEFAULT in MODES else "tile"


def set_mode(mode):
    os.makedirs(STATE_DIR, exist_ok=True)
    tmp = MODE_FILE + ".tmp"
    with open(tmp, "w") as f:
        f.write(mode + "\n")
    os.replace(tmp, MODE_FILE)


class Niri:
    """Requests over niri's IPC socket (one connection, sub-millisecond)."""

    def __init__(self):
        self.sock = socket.socket(socket.AF_UNIX)
        self.sock.connect(os.environ["NIRI_SOCKET"])
        self.f = self.sock.makefile("rw")

    def request(self, req):
        self.f.write(json.dumps(req) + "\n")
        self.f.flush()
        reply = json.loads(self.f.readline())
        if "Err" in reply:
            raise RuntimeError(reply["Err"])
        return reply["Ok"]

    def act(self, name, **args):
        try:
            self.request({"Action": {name: args}})
        except RuntimeError as e:  # e.g. the window closed meanwhile
            print(f"niri-tile: {name}: {e}", file=sys.stderr)

    def windows(self):
        return self.request("Windows")["Windows"]


def layout(wins):
    """{workspace_id: [column, ...]}, each column a list of window ids."""
    skip = {w["workspace_id"] for w in wins
            if (w.get("app_id") or "").startswith(SKIP_APPS)}
    grid = {}
    for w in wins:
        pos = (w.get("layout") or {}).get("pos_in_scrolling_layout")
        ws = w.get("workspace_id")
        if w.get("is_floating") or pos is None or ws is None or ws in skip:
            continue
        grid.setdefault(ws, {}).setdefault(pos[0], []).append((pos[1], w["id"]))
    return {
        ws: [[wid for _, wid in sorted(cols[c])] for c in sorted(cols)]
        for ws, cols in grid.items()
    }


def one_step(niri, cols, mode):
    """Perform a single restructuring action; False when already in shape."""
    if mode == "tile":
        if len(cols[0]) > 1:
            # Master column holds more than one window: expel the bottom one.
            niri.act("ConsumeOrExpelWindowRight", id=cols[0][-1])
            return True
        if len(cols) > 2:
            # A new column appeared: fold it into the stack column.
            niri.act("ConsumeOrExpelWindowLeft", id=cols[2][0])
            return True
        return False
    for col in cols:
        if len(col) > 1:
            niri.act("ConsumeOrExpelWindowRight", id=col[-1])
            return True
    return False


def is_toast(w):
    return (w.get("app_id") == "steam"
            and (w.get("title") or "").startswith("notificationtoasts"))


def write_animations(mode, empty=True):
    """Tile mode: no slide animations, so re-placing a new window is instant.

    niri includes this file (see home/niri.nix) and reloads it on change.
    """
    if not ANIM_FILE:
        return
    # New windows open unfocused so niri never scrolls the view toward the
    # new column (that one-frame jump was a full-screen flash); the daemon
    # focuses them itself once they sit in the stack. They open at the width
    # they will end up with: full on an empty workspace, else half (so a new
    # stack window can be focused at once, without waiting for a resize).
    body = ("animations {\n"
            "    window-movement { off; }\n"
            "    window-resize { off; }\n"
            "    horizontal-view-movement { off; }\n"
            "}\n"
            "window-rule {\n"
            "    open-focused false\n"
            f"    default-column-width {{ proportion {1.0 if empty else 0.5}; }}\n"
            "}\n") if mode == "tile" else ""
    try:
        with open(ANIM_FILE) as f:
            if f.read() == body:
                return
    except OSError:
        pass
    os.makedirs(os.path.dirname(ANIM_FILE), exist_ok=True)
    tmp = ANIM_FILE + ".tmp"
    with open(tmp, "w") as f:
        f.write(body)
    os.replace(tmp, ANIM_FILE)


class Daemon:
    def __init__(self):
        self.applied = {}  # workspace id -> layout signature we last sized
        self.seen = None   # window ids already known (None until first look)
        self.pending = None  # (window id, deadline): focus once it has shrunk
        self.mode = get_mode()
        if not os.path.exists(MODE_FILE):
            set_mode(self.mode)  # so `get`/the bar see the configured default
        self.niri = Niri()

    def arrange(self):
        niri = self.niri
        wins = niri.windows()
        focused = next((w["id"] for w in wins if w.get("is_focused")), None)
        opened = False
        if self.seen is not None and self.mode == "tile":
            # Newly opened windows (opened unfocused, see write_animations)
            # take focus once placed; Steam toasts never do.
            new = [w for w in wins
                   if w["id"] not in self.seen and not is_toast(w)]
            if new:
                focused = max(new, key=lambda w: w["id"])["id"]
                self.pending = None
                opened = True
        self.seen = {w["id"] for w in wins}
        moved = set()  # workspaces we restructured
        for _ in range(64):
            stepped = [ws for ws, cols in layout(wins).items()
                       if one_step(niri, cols, self.mode)]
            if not stepped:
                break
            moved.update(stepped)
            wins = niri.windows()
        for ws, cols in layout(wins).items():
            sig = tuple(map(tuple, cols))
            if self.applied.get(ws) == sig:
                continue  # unchanged: keep any manual resizing the user did
            self.applied[ws] = sig
            width = 100.0 if self.mode == "tile" and len(cols) == 1 else 50.0
            for col in cols:
                niri.act("SetWindowWidth", id=col[0],
                         change={"SetProportion": width})
                if self.mode == "tile":
                    for wid in col:
                        niri.act("ResetWindowHeight", id=wid)
        wins = niri.windows()
        if self.mode == "tile":
            active = next((w["id"] for w in niri.request("Workspaces")["Workspaces"]
                           if w.get("is_focused")), None)
            write_animations(self.mode, empty=not layout(wins).get(active))
        if self.pending:
            focused = self.pending[0]
        if not any(w["id"] == focused for w in wins):
            self.pending, focused = None, None
        now = next((w["id"] for w in wins if w.get("is_focused")), None)
        if focused is None:
            return
        if not (opened or moved or self.pending):
            return  # nothing we did: leave the user's focus alone
        ws = next(w["workspace_id"] for w in wins if w["id"] == focused)
        cols = layout(wins).get(ws)
        if self.mode != "tile" or not cols or len(cols) < 2 or focused in cols[0]:
            self.pending = None
            if now != focused:
                niri.act("FocusWindow", id=focused)
            return
        # The target sits in the stack column. niri only resizes a window when
        # the app redraws, so right after a change a column can still be
        # drawn full width; focusing into it then scrolls the view and pushes
        # the master off screen. In that case hold focus on the master (which
        # also scrolls the view back to the left edge) until the stack shrinks.
        tiles = [w for w in wins if any(w["id"] in c for c in cols)]
        deadline = self.pending[1] if self.pending else time.monotonic() + 1.0
        ready = all(self.shrunk(w) for w in tiles)
        if not ready:
            niri.act("FocusWindow", id=cols[0][0])
            now = cols[0][0]
        if ready or time.monotonic() > deadline:
            self.pending = None
            if now != focused:
                niri.act("FocusWindow", id=focused)
        else:
            self.pending = (focused, deadline)

    def shrunk(self, win):
        """True once the window is no longer (nearly) as wide as its output."""
        ws = next((w for w in self.niri.request("Workspaces")["Workspaces"]
                   if w["id"] == win["workspace_id"]), None)
        out = self.niri.request("Outputs")["Outputs"].get((ws or {}).get("output"))
        width = ((out or {}).get("logical") or {}).get("width")
        return not width or win["layout"]["tile_size"][0] < 0.75 * width

    def run(self):
        events = Niri()
        events.request("EventStream")
        write_animations(self.mode)
        self.arrange()
        last_check = 0.0
        events.sock.setblocking(False)
        buf = b""
        while True:
            ready, _, _ = select.select([events.sock], [], [], 0.2)
            if ready:
                try:
                    chunk = events.sock.recv(1 << 16)
                except BlockingIOError:
                    chunk = None
                if chunk == b"":
                    sys.exit("niri event stream closed")
                buf += chunk or b""
                *lines, buf = buf.split(b"\n")
                if self.mode == "tile" and any(
                        k.encode() in line for line in lines for k in EVENTS):
                    self.arrange()  # immediately: no debounce
            now = time.monotonic()
            if now - last_check < 0.2:
                continue
            last_check = now
            if self.pending and now > self.pending[1]:
                self.arrange()  # fallback: focus the new window anyway
            mode = get_mode()
            if mode != self.mode:
                self.mode = mode
                self.applied.clear()
                self.seen = None
                self.pending = None
                write_animations(mode)
                self.arrange()  # scroll mode: reshape once, then hands off


def watch():
    last = None
    while True:
        mode = get_mode()
        if mode != last:
            print(mode, flush=True)
            last = mode
        time.sleep(0.2)


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "get"
    if cmd == "daemon":
        Daemon().run()
    elif cmd == "set" and len(argv) == 3 and argv[2] in MODES:
        set_mode(argv[2])
    elif cmd == "toggle":
        set_mode("scroll" if get_mode() == "tile" else "tile")
    elif cmd == "get":
        print(get_mode())
    elif cmd == "watch":
        watch()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    try:
        main(sys.argv)
    except (KeyboardInterrupt, BrokenPipeError):
        pass
