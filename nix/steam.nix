{ config, pkgs, inputs, ... }:
{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
    localNetworkGameTransfers.openFirewall = true;
    extraCompatPackages = [
      pkgs.proton-ge-bin
      inputs.proton-cachyos.packages.${pkgs.system}.proton-cachyos
    ];
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };
}
