{ config, pkgs, vitobar, ... }:
{
  imports = [
    ./shell.nix
    ./foot.nix
    ./niri.nix
    ./mako.nix
    ./nvim.nix
    ./nixcord.nix
    ./macchina.nix
    ./oled-refresh.nix
  ];
  
  #create home dir
  home.username      = "vito";
  home.homeDirectory = "/home/vito";
  home.stateVersion  = "25.11";
  
  home.packages = with pkgs; [
    awww
    kdePackages.dolphin
    kdePackages.ark
    kdePackages.gwenview
    kdePackages.kio-extras
    shared-mime-info
    gimp
    grim
    slurp
    btop
    ripgrep
    fd
    gh
    vim
    claude-code
    vitobar.packages.x86_64-linux.default
    easyeffects
    lsp-plugins
    playerctl
    spotify
    protonup-rs
    prismlauncher
  ];

  services.easyeffects.enable = true;
  services.playerctld.enable = true;

  # Helper service that activates graphical-session.target when niri starts.
  # Needed because greetd launches niri directly (not via niri.service),
  # so graphical-session.target never gets pulled in on its own.
  systemd.user.services.niri-session = {
    Unit = {
      Description = "Niri graphical session";
      BindsTo = [ "graphical-session.target" ];
      Before = [ "graphical-session.target" ];
      Wants = [ "graphical-session-pre.target" ];
      After = [ "graphical-session-pre.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
    };
  };

  systemd.user.services.plasma-dolphin = {
    Unit = {
      Description = "Dolphin file manager";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "dbus";
      BusName = "org.freedesktop.FileManager1";
      ExecStart = "${pkgs.kdePackages.dolphin}/bin/dolphin --daemon";
      Environment = [
        "HOME=/home/vito"
        "XDG_CONFIG_HOME=/home/vito/.config"
        "PATH=${pkgs.kdePackages.dolphin}/bin:/run/current-system/sw/bin"
        "QT_QPA_PLATFORM=wayland"
        "QT_QPA_PLATFORMTHEME=qt6ct"
        "QT_PLUGIN_PATH=${pkgs.kdePackages.qtstyleplugin-kvantum}/lib/qt-6/plugins:/run/current-system/sw/lib/qt-6/plugins"
        "XDG_DATA_DIRS=${pkgs.kdePackages.dolphin}/share:${pkgs.kdePackages.kio-extras}/share:${pkgs.shared-mime-info}/share:/run/current-system/sw/share"
      ];
    };
  };

  programs.firefox = {
    enable = true;
    profiles.default.settings = {
      "widget.use-xdg-desktop-portal.mime-handler" = 1;
      "widget.use-xdg-desktop-portal.file-picker" = 1;
      "widget.use-xdg-desktop-portal.open-uri" = 1;
    };
  };

  stylix.targets.firefox.profileNames = [ "default" ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/chrome" = "firefox.desktop";
      "text/html" = "firefox.desktop";
      "application/x-extension-htm" = "firefox.desktop";
      "application/x-extension-html" = "firefox.desktop";
      "application/x-extension-shtml" = "firefox.desktop";
      "application/xhtml+xml" = "firefox.desktop";
      "application/x-extension-xhtml" = "firefox.desktop";
      "application/x-extension-xht" = "firefox.desktop";
      "x-scheme-handler/discord" = "vesktop.desktop";
      "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
      "inode/directory" = "org.kde.dolphin.desktop";
    };
  };

  programs.home-manager.enable = true;
  
  # create wallpaper dir
  home.file."Wallpaper/default.png".source = ../wallpaper/default.png;
  
  #silence gtk warning
  gtk.gtk4.theme = null;
}
