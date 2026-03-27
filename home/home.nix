{ config, pkgs, ... }:
{
  imports = [
    ./shell.nix
    ./foot.nix
    ./niri.nix
    ./mako.nix
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
    neovim
    gh
    vim
  ];

  programs.home-manager.enable = true;
  
  # create wallpaper dir
  xdg.userDirs = {
  enable = true;
  extraConfig = {
    XDG_WALLPAPER_DIR = "${config.home.homeDirectory}/Wallpaper";
  };
  home.file."Wallpaper/default.png".source = /etc/nixos/wallpapers/default.jpg;

};


}
