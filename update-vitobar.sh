#!/usr/bin/env bash
set -euo pipefail

HOST=$(hostname)
VITOBAR_DIR="/home/vito/.config/vitobar"
NIXOS_DIR="/home/vito/.config/nixos"

echo "==> Committing and pushing vitobar changes..."
cd "$VITOBAR_DIR"
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    echo "    No changes to commit, skipping push."
else
    git add -A
    git commit -m "update vitobar"
    git push
fi

echo "==> Updating vitobar flake input..."
cd "$NIXOS_DIR"
nix flake update vitobar

echo "==> Rebuilding NixOS ($HOST)..."
sudo nixos-rebuild switch --flake "$NIXOS_DIR#$HOST"

echo "==> Restarting vitobar..."
pkill -x vitobar || true
sleep 0.5
nohup vitobar >/dev/null 2>&1 &
disown

echo "==> Done! Vitobar updated and restarted."
