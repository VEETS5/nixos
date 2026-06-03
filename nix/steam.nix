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
