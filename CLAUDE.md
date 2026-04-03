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
```

## Architecture

**flake.nix** — Entry point. Defines both host configurations with shared modules. Key inputs: nixpkgs (unstable), home-manager, stylix, nixvim, minegrub-theme, vitobar (custom status bar), nixcord.

**configuration.nix** — Shared system config for both hosts. Uses `let` bindings to branch on hostname for GPU drivers, laptop-only services, and session variables. Imports three sub-modules from `nix/`.

**home/home.nix** — Home-manager entry point importing per-app modules. Each `home/*.nix` file configures one program (foot, niri, mako, nvim, nixcord, macchina, shell).

**home/niri.nix** — Generates `niri/config.kdl` via `xdg.configFile`. Uses Nix string interpolation with `isDesktop` conditionals for monitor layout and keybind differences (monitor focus vs window focus on J/K).

**nix/grub.nix** — GRUB with `efiInstallAsRemovable = true` and systemd-boot force-disabled. This is intentional — do not re-enable systemd-boot or set `canTouchEfiVariables = true`.

**nix/stylix.nix** — Takes `wallpaper` as a function argument (not standard module args). Theme is catppuccin-mocha. GRUB styling is disabled in stylix (minegrub handles it).

**hosts/**/hardware-configuration.nix** — Machine-specific hardware configs (generated, rarely hand-edited).

## Key Patterns

- The vitobar flake input is passed through `specialArgs` and `extraSpecialArgs` so both system and home-manager modules can access it.
- Stylix is imported as a function call `(import ./nix/stylix.nix { inherit pkgs wallpaper; })` rather than a standard module import, because it needs the wallpaper path.
- Home-manager is configured inline in flake.nix with `useGlobalPkgs = true` and `useUserPackages = true`.
