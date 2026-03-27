{ config, pkgs, ... }:
{
  imports = [
    ./shell.nix
    ./foot.nix
    ./niri.nix
    ./mako.nix
    ./nvim.nix
  ];
  
  #create home dir
  home.username      = "vito";
  home.homeDirectory = "/home/vito";
  home.stateVersion  = "25.11";
  
  home.packages = with pkgs; [
    firefox
    fuzzel
    swww
    grim
    slurp
    btop
    ripgrep
    fd
    gh
    vim
  ];

  programs.home-manager.enable = true;
  
  # create wallpaper dir
  home.file."Wallpaper/default.png".source = ../wallpaper/default.png;
}
