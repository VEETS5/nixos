#!/usr/bin/env bash
# Set the system wallpaper. Stylix regenerates the colorscheme from the image,
# so everything (foot, niri, GTK, nvim, mako, greeter, vitobar) follows.
#
# Usage: wp <image>        (alias for: bash ~/.config/nixos/set-wallpaper.sh)
set -euo pipefail

IMG="${1:-}"
if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
    echo "usage: wp <image>" >&2
    exit 1
fi

NIXOS_DIR="$HOME/.config/nixos"
HOST=$(hostname)

# Normalize to wallpaper/wallpaper.<ext> (keep extension so image loaders are happy)
base=$(basename "$IMG")
ext="${base##*.}"
[ "$ext" = "$base" ] && ext="img"
dest="$NIXOS_DIR/wallpaper/wallpaper.${ext,,}"

echo "==> Installing $base as wallpaper..."
rm -f "$NIXOS_DIR"/wallpaper/*
cp "$IMG" "$dest"

cd "$NIXOS_DIR"
git add wallpaper/
git commit -m "wallpaper: $base" || echo "    (no change to commit)"

echo "==> Rebuilding NixOS ($HOST)..."
sudo nixos-rebuild switch --flake "$NIXOS_DIR#$HOST"

echo "==> Pushing..."
git push || echo "    (push failed — commit is local, push manually later)"

echo "==> Swapping wallpaper live..."
awww img "$dest" || true

echo "==> Restarting vitobar with new palette..."
pkill -x vitobar || true
sleep 0.5
nohup vitobar >/dev/null 2>&1 &
disown

echo "==> Done! New windows use the new colors; log out/in (Mod+Shift+E) to restyle everything."
