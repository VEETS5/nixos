{ config, pkgs, ... }:
{
  services.mako = {
    enable = true;
    settings = {
      default-timeout  = 5000;
      background-color = "#192330";
      text-color       = "#cdcecf";
      border-color     = "#719cd6";
      border-radius    = 8;
      border-size      = 2;
      font             = "JetBrainsMono Nerd Font 10";
    };
  };
}
