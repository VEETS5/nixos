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
    swww
    # ── KDE application suite (apps only — no Plasma desktop) ──────────────────
    kdePackages.dolphin          # file manager
    kdePackages.ark              # archive manager
    kdePackages.gwenview         # image viewer
    kdePackages.okular           # PDF / document viewer
    kdePackages.kate             # text editor
    kdePackages.kcalc            # calculator
    kdePackages.kdialog          # native KDE dialogs for scripts/CLI
    kdePackages.filelight        # disk-usage visualiser
    kdePackages.spectacle        # screenshot tool
    kdePackages.kio-extras       # extra KIO protocols (mtp:/, sftp:/, etc.)
    kdePackages.kimageformats    # webp/avif/heif thumbnails in Dolphin/Gwenview
    kdePackages.qtsvg            # SVG rendering for KDE app icons/thumbnails
    haruna
    chromium          # open-source Chromium browser (not Google Chrome)
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
    copyq
    satty
    spotify
    protonup-rs
    prismlauncher
    r2modman
    cloudflared
    jdk
    wlsunset
    # gamescope without the cap_sys_nice setcap wrapper. Steam launches games
    # under no_new_privs, which forbids gaining file capabilities on exec, so
    # /run/wrappers/bin/gamescope aborts with "failed to inherit capabilities"
    # and the game instantly returns to "Play". This plain build runs fine
    # (only loses realtime scheduling priority). Used in FH6 launch options.
    (writeShellScriptBin "gamescope-nocap" ''
      exec ${gamescope}/bin/gamescope "$@"
    '')
  ];

  services.easyeffects.enable = true;
  services.playerctld.enable = true;

  # Terminal Spotify client (replaces ncspot). The default pkgs.spotify-player
  # already builds with image + sixel + streaming enabled, and the default
  # rodio audio backend goes through ALSA -> the PipeWire we already run, so it
  # adds no new audio deps (alsa-lib is already in the closure).
  programs.spotify-player = {
    enable = true;
    settings = {
      # Real-time 64-band frequency bar chart in the playback window. Off by
      # default; needs the streaming feature (on) + local librespot playback.
      enable_audio_visualization = true;
    };
  };

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
}
