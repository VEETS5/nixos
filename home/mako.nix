{ config, pkgs, lib, ... }:
{
  services.mako = {
    enable = true;
    settings = {
      default-timeout  = 5000;
      border-radius    = 8;
      border-size      = 2;
    };
  };
}
