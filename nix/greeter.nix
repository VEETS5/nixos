{ pkgs, vitobar, ... }:
let
  vitobarPkg = vitobar.packages.x86_64-linux.default;
in
{
  users.users.greeter.extraGroups = [ "seat" "video" ];

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.cage}/bin/cage -s -- ${vitobarPkg}/bin/vitogreeter";
        user = "greeter";
      };
    };
  };
}
