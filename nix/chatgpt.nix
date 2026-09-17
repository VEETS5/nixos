{ pkgs }:
let
  app = pkgs.runCommand "chatgpt-linux-26.903.71938" {
    src = pkgs.fetchurl {
      url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb";
      hash = "sha256-E/Rt9zsG324T6edQsvPImphYY3QeqCXS01b1JVn1Wr0=";
    };
    nativeBuildInputs = [ pkgs.binutils pkgs.xz ];
  } ''
    mkdir -p "$out"
    ar p "$src" data.tar.xz | tar -xJ -C "$out"
  '';
in
pkgs.buildFHSEnv {
  name = "chatgpt";
  targetPkgs = p: with p; [
    alsa-lib at-spi2-core cairo cups dbus expat gdk-pixbuf glib gtk3 libdrm libgbm
    libGL libnotify libusb1 libxkbcommon nspr nss pango systemd
    libx11 libxcb libxcomposite libxdamage libxext libxfixes libxrandr
    stdenv.cc.cc.lib xdg-utils git xz
  ];
  runScript = "${app}/usr/lib/chatgpt/ChatGPT";
  extraInstallCommands = ''
    mkdir -p "$out/share/applications" "$out/share/pixmaps"
    cp ${app}/usr/share/applications/chatgpt.desktop "$out/share/applications/"
    cp ${app}/usr/share/pixmaps/chatgpt.png "$out/share/pixmaps/"
    substituteInPlace "$out/share/applications/chatgpt.desktop" \
      --replace-fail 'Exec=chatgpt %U' "Exec=$out/bin/chatgpt --ozone-platform=wayland %U"
  '';
  meta = {
    description = "Official ChatGPT Linux desktop app";
    platforms = [ "x86_64-linux" ];
    mainProgram = "chatgpt";
  };
}
