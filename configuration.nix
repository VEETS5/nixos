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
    # Force GTK apps (Steam, etc.) to route their file dialogs through the xdg
    # portal instead of drawing their own bundled GTK file chooser — without
    # this, Steam's "Add Non-Steam Game / Browse" ignores the portal entirely
    # and shows the GNOME-style picker regardless of the portal config above.
    GTK_USE_PORTAL     = "1";
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

  # seatd.service upstream uses Type=notify and bridges seatd's readiness (its
  # `-n` fd flag) into systemd via `s6-notify-socket-from-fd`. That bridge is
  # broken under systemd 260.1 (PID1 logs "Extra notification messages sent with
  # BARRIER=1, ignoring everything"), so systemd never sees seatd reach "ready",
  # hits TimeoutStartSec=90s, and SIGTERMs seatd. niri is a libseat *client* of
  # seatd, so when seatd dies niri loses its seat (DRM master + input) and exits
  # cleanly — which collapses the whole graphical session back to the greeter
  # every ~90s, with no niri coredump. Run seatd directly as a plain service so
  # there is no readiness handshake to time out. (seatd creates /run/seatd.sock
  # immediately on start; niri connects at runtime, so no ordering is lost.)
  systemd.services.seatd.serviceConfig = {
    Type = lib.mkForce "simple";
    ExecStart = lib.mkForce "${lib.getExe' pkgs.seatd "seatd"} -u root -g seat -l info";
  };

  # ── Portal ──────────────────────────────────────────────────────────────────
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = false;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
    # niri's package ships its own niri-portals.conf (default=gnome;gtk). Because
    # XDG_CURRENT_DESKTOP=niri, xdg-desktop-portal loads that desktop-specific
    # file *first*, so it overrides `config.common` and forces the GTK/GNOME file
    # picker no matter what we set there. We override the niri config here: NixOS
    # writes it to /etc/xdg/xdg-desktop-portal/niri-portals.conf, which wins over
    # the copy in the niri package's /share. FileChooser -> KDE (Dolphin-style
    # dialog); ScreenCast/Screenshot stay on gnome so niri screen-sharing keeps
    # working; secrets stay on gnome-keyring (the running keyring daemon).
    config = {
      common.default = [ "kde" ];
      niri = {
        default = [ "gnome" "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
        "org.freedesktop.impl.portal.Access" = [ "gtk" ];
        "org.freedesktop.impl.portal.Notification" = [ "gtk" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
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
    swaytools
    swayidle
    cava
    unzip
    glib
    protontricks
    davinci-resolve
  ];
  
  system.stateVersion = "25.11";
}
