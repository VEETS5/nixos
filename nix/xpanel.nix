# Finalmouse XPANEL Desktop — companion app for ULX / Centerpiece Pro.
#
# Distributed only as an AppImage, so we repackage it with appimageTools
# (wrapType2) which patches the bundled binaries against the Nix store and
# gives us a normal `xpanel-desktop` command + launcher entry.
#
# The udev rules (vendor 361d / 1fc9) are taken verbatim from
# github.com/teamfinalmouse/xpanel-linux-permissions and grant the logged-in
# user access to the device via TAG+="uaccess" (logind), so XPANEL can talk to
# the mouse without root.
{ config, lib, pkgs, ... }:

let
  pname   = "xpanel-desktop";
  version = "1.1.1";

  src = pkgs.fetchurl {
    url    = "https://github.com/teamfinalmouse/xpanel-desktop-public/releases/download/v${version}/xpanel-desktop-${version}.AppImage";
    sha256 = "1iyk9r0cdq9a0ghmbn5jaqzqm5215ds876kn8sfm3lgmj6jihhw2";
  };

  appimageContents = pkgs.appimageTools.extractType2 { inherit pname version src; };

  # Must be a 70-* file: the uaccess ACL is applied by 73-seat-late.rules, so a
  # TAG+="uaccess" rule has to run *before* priority 73. services.udev.extraRules
  # lands at 99-local.rules (too late), so we ship a properly-named file instead.
  finalmouseRules = pkgs.writeTextFile {
    name = "70-finalmouse-udev-rules";
    destination = "/etc/udev/rules.d/70-finalmouse.rules";
    text = ''
      # Finalmouse ULX devices - USB access
      SUBSYSTEM=="usb", ATTR{idVendor}=="361d", ATTR{idProduct}=="0100", MODE="0660", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTR{idVendor}=="361d", ATTR{idProduct}=="0101", MODE="0660", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTR{idVendor}=="361d", ATTR{idProduct}=="0102", MODE="0660", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTR{idVendor}=="361d", ATTR{idProduct}=="0103", MODE="0660", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTR{idVendor}=="361d", ATTR{idProduct}=="0104", MODE="0660", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTR{idVendor}=="361d", ATTR{idProduct}=="0111", MODE="0660", TAG+="uaccess"

      # Finalmouse ULX devices - HID access
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="361d", ATTRS{idProduct}=="0100", MODE="0660", TAG+="uaccess"
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="361d", ATTRS{idProduct}=="0101", MODE="0660", TAG+="uaccess"
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="361d", ATTRS{idProduct}=="0102", MODE="0660", TAG+="uaccess"
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="361d", ATTRS{idProduct}=="0104", MODE="0660", TAG+="uaccess"

      # Finalmouse Centerpiece Pro devices - USB access
      SUBSYSTEM=="usb", ATTRS{idVendor}=="361d", ATTRS{idProduct}=="0200", MODE="0660", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="361d", ATTRS{idProduct}=="0201", MODE="0660", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="361d", ATTRS{idProduct}=="0202", MODE="0660", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="361d", ATTRS{idProduct}=="0203", MODE="0660", TAG+="uaccess"

      # Finalmouse Centerpiece Pro devices - HID access
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="361d", ATTRS{idProduct}=="0200", MODE="0660", TAG+="uaccess"
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="361d", ATTRS{idProduct}=="0201", MODE="0660", TAG+="uaccess"
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="361d", ATTRS{idProduct}=="0202", MODE="0660", TAG+="uaccess"
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="361d", ATTRS{idProduct}=="0203", MODE="0660", TAG+="uaccess"
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1fc9", ATTRS{idProduct}=="0021", MODE="0660", TAG+="uaccess"
    '';
  };

  xpanel = pkgs.appimageTools.wrapType2 {
    inherit pname version src;

    # Electron runtime libs not in appimageTools' default FHS env.
    extraPkgs = pkgs: with pkgs; [
      xorg.libxshmfence
      libGL
      libdrm
      mesa
    ];

    extraInstallCommands = ''
      install -Dm444 ${appimageContents}/${pname}.desktop \
        $out/share/applications/${pname}.desktop
      substituteInPlace $out/share/applications/${pname}.desktop \
        --replace 'Exec=AppRun' 'Exec=${pname}'
      install -Dm444 ${appimageContents}/${pname}.png \
        $out/share/icons/hicolor/256x256/apps/${pname}.png
    '';
  };
in
{
  environment.systemPackages = [ xpanel ];

  services.udev.packages = [ finalmouseRules ];
}
