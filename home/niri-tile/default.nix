# niri-tile: Hyprland-style (non-scrolling) tiling for niri, plus a Noctalia
# bar widget showing the current mode. Super+T = tiling, Super+A = scrolling.
{ config, pkgs, lib, ... }:
let
  # Mode used after login (the mode lives in $XDG_RUNTIME_DIR, so a reboot
  # resets to this). Change to "scroll" to make niri's normal layout the default.
  defaultMode = "tile";

  niri-tile = pkgs.writers.writePython3Bin "niri-tile" {
    flakeIgnore = [ "E501" "W503" ];
  } (builtins.readFile ./niri-tile.py);
  bin = lib.getExe niri-tile;
in
{
  home.packages = [ niri-tile ];

  systemd.user.services.niri-tile = {
    Unit = {
      Description = "niri-tile layout daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${bin} daemon";
      Environment = [
        "NIRI_TILE_DEFAULT=${defaultMode}"
        # Included by niri's config (home/niri.nix): tile mode turns off the
        # slide animations there so re-placing a new window is instant.
        "NIRI_TILE_ANIMATIONS=${config.xdg.stateHome}/niri-tile/animations.kdl"
      ];
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  xdg.dataFile."noctalia/plugins/tilemode/plugin.toml".source = ./plugin/plugin.toml;
  xdg.dataFile."noctalia/plugins/tilemode/tilemode.luau".text =
    builtins.replaceStrings [ "@niriTile@" ] [ bin ] (builtins.readFile ./plugin/tilemode.luau);

  programs.noctalia.settings = {
    plugins.enabled = [ "local/tilemode" ];
    widget.tilemode.type = "local/tilemode:tilemode";
    # Far left, before the launcher (Noctalia's default start list otherwise).
    bar.default.start = [ "tilemode" "launcher" "wallpaper" "workspaces" ];
  };
}
