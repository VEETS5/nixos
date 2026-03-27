{ config, pkgs, ... }:
{
  imports = [
    ./shell.nix
    ./foot.nix
    ./niri.nix
    ./mako.nix
  ];

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
}
