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

# Change wallpaper (copies image, commits, rebuilds, pushes, restarts Noctalia; stylix regenerates the whole colorscheme from the image)
wp <image>          # alias for: bash ~/.config/nixos/set-wallpaper.sh
```

## Architecture

**flake.nix** — Entry point. Defines both host configurations with shared modules. Key inputs: nixpkgs (unstable), home-manager, stylix, nixvim, minegrub-theme, nixcord.

**configuration.nix** — Shared system config for both hosts. Uses `let` bindings to branch on hostname for GPU drivers, laptop-only services, and session variables. Imports three sub-modules from `nix/`.

**home/home.nix** — Home-manager entry point importing per-app modules. Each `home/*.nix` file configures one program (foot, niri, noctalia, nvim, nixcord, macchina, shell).

**home/niri.nix** — Generates `niri/config.kdl` via `xdg.configFile`. Uses Nix string interpolation with `isDesktop` conditionals for monitor layout and keybind differences (monitor focus vs window focus on J/K).

**nix/grub.nix** — GRUB with `efiInstallAsRemovable = true` and systemd-boot force-disabled. This is intentional — do not re-enable systemd-boot or set `canTouchEfiVariables = true`.

**nix/stylix.nix** — Takes `wallpaper` as a function argument (not standard module args). No pinned base16 scheme: stylix auto-generates a dark palette from the wallpaper image, so the theme always matches it. GRUB styling is disabled in stylix (minegrub handles it).

**Wallpaper flow** — `configuration.nix` selects the image in `wallpaper/`. `set-wallpaper.sh` (`wp` alias) replaces it, commits, rebuilds, pushes, and restarts Noctalia. Stylix supplies the shell palette, font, wallpaper, application themes, and Niri focus colors. Noctalia app-theme templates are disabled to avoid competing with Stylix. GUI settings can override Noctalia defaults; keep shared theme changes in Nix.

**Desktop shell** — `home/noctalia.nix` uses the pinned nixpkgs package and Home Manager service. `nix/greeter.nix` enables Noctalia Greeter with matching Stylix colors. Niri session entries are linked into the system profile with `environment.pathsToLink`: greetd login replaces service-level `XDG_DATA_DIRS`, so relying on that variable hides Niri and produces a Shell-only login. The greeter launches the packaged Niri session, which manages the graphical-session target. Mod+Space opens the launcher, Mod+Comma settings, Mod+Shift+Comma control center, and Mod+Backslash toggles the bar.

**Vitobar** — The independent repository at `~/.config/vitobar` is preserved for development. It is no longer a flake input, installed package, greeter, or startup command here.

**hosts/**/hardware-configuration.nix** — Machine-specific hardware configs (generated, rarely hand-edited).

## Key Patterns

- Stylix is imported as a function call `(import ./nix/stylix.nix { inherit pkgs wallpaper; })` rather than a standard module import, because it needs the wallpaper path.
- Home-manager is configured inline in flake.nix with `useGlobalPkgs = true` and `useUserPackages = true`.
