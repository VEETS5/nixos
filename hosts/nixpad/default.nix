# Machine-specific config for nixpad. Anything that should only exist on this
# machine goes here; shared config stays in configuration.nix / home/.
# The two package lists below are managed by nixman (hand edits are fine:
# keep one package attribute per line).
{ pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "nixpad";

  # System packages for nixpad only.
  environment.systemPackages = with pkgs; [
  ];

  # Home-manager packages for vito on nixpad only.
  home-manager.users.vito.home.packages = with pkgs; [
  ];
}
