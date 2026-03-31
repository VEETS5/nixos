{ config, pkgs, inputs, ... }:

let
  hostname  = config.networking.hostName;
  isLaptop  = hostname == "nixpad";
  isDesktop = hostname == "nixtop";
  gpuType   = if isDesktop then "amd" else "intel";
  wallpaper = ./wallpaper/default.png;
in
{
  imports = [
    ./nix/steam.nix
    (import ./nix/stylix.nix { inherit pkgs wallpaper; })
    ./nix/grub.nix
  ];
  # ── Bootloader ──────────────────────────────────────────────────────────────
   boot.loader.efi.canTouchEfiVariables = true;
  # ── Networking ──────────────────────────────────────────────────────────────
  networking.networkmanager.enable = true;

  # ── Locale ──────────────────────────────────────────────────────────────────
  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";
  services.xserver.xkb = { layout = "us"; variant = ""; };

  # ── User ────────────────────────────────────────────────────────────────────
  users.users.vito = {
    isNormalUser = true;
    description  = "Vito Torina";
    extraGroups  = [ "networkmanager" "wheel" "seat" "video" "audio" "input" ];
  };

  # ── Nix ─────────────────────────────────────────────────────────────────────
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Wayland settings
  programs.xwayland.enable = true;
  # ── GPU ─────────────────────────────────────────────────────────────────────
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs;
      if gpuType == "amd" then [
        rocmPackages.clr.icd
      ] else [
        intel-media-driver
        libvdpau-va-gl
      ];
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME  = if gpuType == "intel" then "iHD" else "";
    NIXOS_OZONE_WL     = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  # ── Niri ────────────────────────────────────────────────────────────────────
  programs.niri.enable = true;
  services.seatd.enable = true;
  security.polkit.enable = true;

  # ── Portal ──────────────────────────────────────────────────────────────────
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    config.common.default = "*";
  };

  # ── Audio ───────────────────────────────────────────────────────────────────
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ── Fonts ───────────────────────────────────────────────────────────────────
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-color-emoji
      nerd-fonts.jetbrains-mono
    ];
    fontconfig.defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font" ];
      sansSerif = [ "Noto Sans" ];
      serif     = [ "Noto Serif" ];
      emoji     = [ "Noto Color Emoji" ];
    };
  };

  # ── Laptop-only ─────────────────────────────────────────────────────────────
  services.upower.enable = isLaptop;

  # ── System packages ─────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    git
    wget
    curl
    neovim
    wl-clipboard
    brightnessctl
    nodejs
    rustup
    pkg-config
    wayland
    xwayland-satellite
    libxkbcommon
    gcc
    wayland-scanner
    libxkbcommon.dev
    wayland.dev
  ];
  
  environment.sessionVariables = {
    PKG_CONFIG_PATH = "/run/current-system/sw/lib/pkgconfig:/run/current-system/sw/share/pkg  config";
  };
  
  system.stateVersion = "25.11";
}
