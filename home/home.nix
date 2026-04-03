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
  ];
  
  #create home dir
  home.username      = "vito";
  home.homeDirectory = "/home/vito";
  home.stateVersion  = "25.11";
  
  home.packages = with pkgs; [
    firefox
    swww
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
  ];

  services.easyeffects.enable = true;

  programs.home-manager.enable = true;
  
  # create wallpaper dir
  home.file."Wallpaper/default.png".source = ../wallpaper/default.png;
  
  #silence gtk warning
  gtk.gtk4.theme = null;
}
