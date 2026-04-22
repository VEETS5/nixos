{ config, pkgs, lib, inputs, ... }:

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
    ./nix/greeter.nix
  ];
  # ── Bootloader ──────────────────────────────────────────────────────────────
   boot.loader.efi.canTouchEfiVariables = false;

  # ── Hibernation ─────────────────────────────────────────────────────────────
  # amdgpu hangs under s2idle and during runtime PM, which crashes the box
  # mid-hibernate and leaves no valid image to resume from. Force deep S3 and
  # disable amdgpu runtime PM on the desktop. Also pass resume= explicitly in
  # UUID= form so the initramfs finds the swap partition regardless of how
  # GRUB's os-prober flow rewrites the cmdline.
  boot.kernelParams = lib.optionals isDesktop [
    "mem_sleep_default=deep"
    "amdgpu.runpm=0"
    "resume=UUID=4c3e969c-424b-4194-ae10-db2fe2f555c3"
  ];

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

  # Lets generic-linux dynamically-linked binaries run (e.g. uv's prebuilt Python).
  programs.nix-ld.enable = true;

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
    PKG_CONFIG_PATH    = "/run/current-system/sw/lib/pkgconfig:/run/current-system/sw/share/pkgconfig";
    XDG_DATA_DIRS       = lib.mkForce [
      "/run/current-system/sw/share"
      "/home/vito/.nix-profile/share"
      "/etc/profiles/per-user/vito/share"
    ];
  };

  # ── Niri ────────────────────────────────────────────────────────────────────
  programs.niri.enable = true;
  services.seatd.enable = true;
  security.polkit.enable = true;

  # ── Portal ──────────────────────────────────────────────────────────────────
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = false;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
    config.common = {
      default = [ "kde" ];
    };
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

  # ── Dolphin dependencies ─────────────────────────────────────────────────────
  services.udisks2.enable = true;

  # ── Laptop-only ─────────────────────────────────────────────────────────────
  services.upower.enable = isLaptop;

  # ── System packages ─────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    git
    wget
    curl
    efibootmgr
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
  
  system.stateVersion = "25.11";
}
