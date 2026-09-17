{ config, pkgs, inputs, ... }:
let
  proton-ge-9-20 = pkgs.proton-ge-bin.overrideAttrs (old: rec {
    version = "GE-Proton9-20";
    src = pkgs.fetchzip {
      url = "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${version}/${version}.tar.gz";
      hash = "sha256-1twCv81KO1fcRcIb4H7VtAjtcKrX+DymsYdf885eOWo=";
    };
    preFixup = "";
  });
in
{
  # Fix Steam menus closing immediately on Niri with xwayland-satellite 0.8.2.
  # Remove once nixpkgs includes https://github.com/Supreeeme/xwayland-satellite/pull/494.
  nixpkgs.overlays = [
    (final: prev: {
      xwayland-satellite = prev.xwayland-satellite.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          (prev.fetchurl {
            url = "https://github.com/Supreeeme/xwayland-satellite/commit/add2795134593faafce60e404a0a75df68e9ee0c.patch";
            hash = "sha256-XD93f8m8h0o0Vs3QcmWkHGGi5mZwf9wkx9qEiq6sjnw=";
          })
        ];
      });
    })
  ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
    localNetworkGameTransfers.openFirewall = true;
    extraCompatPackages = [
      pkgs.proton-ge-bin
      proton-ge-9-20
      inputs.proton-cachyos.packages.${pkgs.system}.proton-cachyos
    ];
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };
}
