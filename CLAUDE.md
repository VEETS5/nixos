# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A NixOS flake-based system configuration for two machines:
- **nixtop** — Desktop (AMD CPU/GPU, dual monitor: 2560x1440@240Hz + 1920x1200@60Hz)
- **nixpad** — Laptop (Intel CPU/GPU, touchpad, brightness control, upower)

Host-specific behavior is driven by `config.networking.hostName` checks (e.g., `isDesktop = hostname == "nixtop"`).

## Common Commands

```bash
# Rebuild and switch (run from anywhere)
sudo nixos-rebuild switch --flake ~/.config/nixos#nixtop   # desktop
sudo nixos-rebuild switch --flake ~/.config/nixos#nixpad   # laptop

# Update flake inputs
nix flake update --flake ~/.config/nixos

# Test build without switching
nixos-rebuild build --flake ~/.config/nixos#nixtop
bash ~/.config/nixos/tests/check-login.sh ./result
bash ~/.config/nixos/tests/check-wallpaper.sh

# Change wallpaper (copies image, commits, rebuilds, pushes, restarts Noctalia; stylix regenerates the whole colorscheme from the image)
wp <image>          # alias for: bash ~/.config/nixos/set-wallpaper.sh
```

## Architecture

**flake.nix** — Entry point. `mkHost` builds each host from `hosts/<name>/` plus the shared modules. Key inputs: nixpkgs (unstable), home-manager, stylix, nixvim, minegrub-theme, nixcord.

**configuration.nix** — Shared system config for both hosts. Uses `let` bindings to branch on hostname for GPU drivers, laptop-only services, and session variables. Imports three sub-modules from `nix/`.

**home/home.nix** — Home-manager entry point importing per-app modules. Each `home/*.nix` file configures one program (foot, niri, noctalia, nvim, nixcord, macchina, shell).

**home/niri.nix** — Generates `niri/config.kdl` via `xdg.configFile`. Uses Nix string interpolation with `isDesktop` conditionals for monitor layout and keybind differences (monitor focus vs window focus on J/K).

**home/niri-tile/** — `niri-tile` user daemon that fakes a non-scrolling layout on niri over IPC (master left, rest stacked right; Mod+T tile / Mod+A scroll; mode in `$XDG_RUNTIME_DIR/niri-tile/mode`, default set by `defaultMode`), plus a local Noctalia plugin `local/tilemode` showing the mode at the far left of the bar.

**nix/grub.nix** — GRUB with `efiInstallAsRemovable = true` and systemd-boot force-disabled. This is intentional — do not re-enable systemd-boot or set `canTouchEfiVariables = true`.

**nix/stylix.nix** — Takes `wallpaper` as a function argument (not standard module args). No pinned base16 scheme: stylix auto-generates a dark palette from the wallpaper image, so the theme always matches it. GRUB styling is disabled in stylix (minegrub handles it).

**Wallpaper flow** — `configuration.nix` selects the image in `wallpaper/`. `set-wallpaper.sh` (`wp` alias) replaces it, commits, rebuilds, pushes, and restarts Noctalia. Stylix supplies the shell palette, font, wallpaper, application themes, and Niri focus colors. Noctalia app-theme templates are disabled to avoid competing with Stylix. Noctalia’s wallpaper-change hook opens a terminal to run the same `wp` rebuild with sudo. It compares the selected image with the applied Stylix image to avoid restart loops. A separate systemd user unit survives shell restarts and allows one rebuild at a time; if another wallpaper is selected while busy, reselect it after the rebuild finishes. The selected image drives one global Stylix palette, even with per-monitor wallpapers. Other GUI theme overrides can still override Noctalia defaults.

**Desktop shell** — `home/noctalia.nix` uses the pinned nixpkgs package and Home Manager service. `nix/greeter.nix` enables Noctalia Greeter with matching Stylix colors. Niri session entries are linked into the system profile with `environment.pathsToLink`: greetd login replaces service-level `XDG_DATA_DIRS`, so relying on that variable hides Niri and produces a Shell-only login. The greeter launches the packaged Niri session, which manages the graphical-session target. Mod+Space opens the launcher, Mod+Comma settings, Mod+Shift+Comma control center, and Mod+Backslash toggles the bar.

**Vitobar** — The independent repository at `~/.config/vitobar` is preserved for development. It is no longer a flake input, installed package, greeter, or startup command here.

**hosts/<name>/default.nix** — Machine-specific module: hostname, hardware import, and machine-only system + home-manager package lists (managed by nixman, one attribute per line).

**hosts/**/hardware-configuration.nix** — Machine-specific hardware configs (generated, rarely hand-edited).

## Key Patterns

- Stylix is imported as a function call `(import ./nix/stylix.nix { inherit pkgs wallpaper; })` rather than a standard module import, because it needs the wallpaper path.
- Home-manager is configured inline in flake.nix with `useGlobalPkgs = true` and `useUserPackages = true`.

## nixman

nixman (TUI for packages, flake inputs, rebuilds, git) lives in its own public repo, github:VEETS5/nixman (local checkout: `~/.config/nixman`, GPL-3.0). It is the `nixman` flake input here and installed on every host from flake.nix. To ship a nixman change: push it in ~/.config/nixman, then `nix flake update nixman` here and rebuild.

- It edits the four lists for a host: `configuration.nix` (system, all), `home/home.nix` (home, all), and the two lists in `hosts/<host>/default.nix`. Keep entries one attribute per line; anything else in a list is preserved as "unmanaged".
- Rebuilds only ever target the current hostname and verify the built store path name before switching (guards against the wrong-host boot loop).
- `system.configurationRevision` is set from the flake rev so nixman can show whether this machine is behind HEAD.
