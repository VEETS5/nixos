#!/usr/bin/env bash
# Set the system wallpaper. Stylix regenerates the colorscheme from the image,
# so everything (foot, niri, GTK, nvim, greeter, Noctalia) follows.
#
# Usage: wp <image>        (alias for: bash ~/.config/nixos/set-wallpaper.sh)
set -euo pipefail

IMG="${1:-}"
if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
    echo "usage: wp <image>" >&2
    exit 1
fi

NIXOS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
HOST=$(hostname)

# Also serialize direct `wp` calls with rebuilds started by Noctalia.
exec 9> "$NIXOS_DIR/.git/wallpaper.lock"
flock -n 9 || { echo "A wallpaper rebuild is already running." >&2; exit 1; }

# Normalize to wallpaper/wallpaper.<ext> (keep extension so image loaders are happy)
base=$(basename "$IMG")
ext="${base##*.}"
[ "$ext" = "$base" ] && ext="img"
dest="$NIXOS_DIR/wallpaper/wallpaper.${ext,,}"

echo "==> Installing $base as wallpaper..."
# Copy first: the chosen image may already live inside wallpaper/.
staged=$(mktemp "$NIXOS_DIR/.git/wallpaper.XXXXXX")
trap 'rm -f -- "$staged"' EXIT
cp -- "$IMG" "$staged"
rm -f "$NIXOS_DIR"/wallpaper/*
mv -- "$staged" "$dest"

cd "$NIXOS_DIR"
git add wallpaper/
if ! git diff --cached --quiet -- wallpaper/; then
    git commit --only -m "wallpaper: $base" -- wallpaper/
fi

echo "==> Rebuilding NixOS ($HOST)..."
sudo nixos-rebuild switch --flake "$NIXOS_DIR#$HOST"

echo "==> Pushing..."
git push || echo "    (push failed — commit is local, push manually later)"

# Home Manager restarts Noctalia when its Stylix palette or wallpaper changes.
systemctl --user restart noctalia.service

echo "==> Done! New windows use the new colors; log out/in (Mod+Shift+E) to restyle everything."
