# WireGuard VPN to serchadver.
#
# Split-tunnel: only 10.8.0.0/24 is routed over the tunnel (AllowedIPs from
# laptop.conf), so normal internet traffic is unaffected.
#
# Laptop-only (nixpad): the 10.8.0.6 address is specific to this peer.
#
# The private key is NOT inlined here (this repo is git-tracked and the Nix
# store is world-readable). It lives at /etc/wireguard/laptop.key (root, 0600)
# and is referenced via privateKeyFile.
{ config, lib, pkgs, ... }:

let
  isLaptop = config.networking.hostName == "nixpad";
in
{
  networking.wg-quick.interfaces = lib.mkIf isLaptop {
    wg0 = {
      address = [ "10.8.0.6/24" ];
      privateKeyFile = "/etc/wireguard/laptop.key";

      peers = [
        {
          publicKey = "W+oigUzL1SBu6Q7AzKHRWFYpopjAkbbzXx1Ka7jfgFk=";
          endpoint = "serchadver.duckdns.org:51820";
          allowedIPs = [ "10.8.0.0/24" ];
          persistentKeepalive = 25;
        }
      ];
    };
  };

  # wg / wg-quick CLI tools.
  environment.systemPackages = lib.mkIf isLaptop [ pkgs.wireguard-tools ];
}
