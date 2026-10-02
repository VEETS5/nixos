#!/usr/bin/env bash
# Usage: bash tests/check-login.sh ./result
# Noctalia's fallback lookup must work even when login replaces XDG_DATA_DIRS.
set -euo pipefail
system="${1:?Pass a built NixOS system path}"
session="$system/sw/share/wayland-sessions/niri.desktop"
test -r "$session"
grep -qx 'Name=Niri' "$session"
grep -qx 'Exec=niri-session' "$session"
test -x "$system/sw/bin/niri-session"
test -x "$system/sw/bin/noctalia-greeter-session"
echo 'PASS: Noctalia can discover Niri in the system profile and its session command exists.'
