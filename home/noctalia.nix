{ config, lib, pkgs, ... }:
let
  rebuildWallpaper = pkgs.writeShellScript "rebuild-stylix-wallpaper" ''
    ${pkgs.bash}/bin/bash ${lib.escapeShellArg "${config.home.homeDirectory}/.config/nixos/set-wallpaper.sh"} "$1"
    status=$?
    if [ "$status" -ne 0 ]; then
      read -r -p "Wallpaper rebuild failed. Press Enter to close."
    fi
    exit "$status"
  '';
  wallpaperHook = pkgs.writeShellScript "noctalia-stylix-wallpaper" ''
    image="''${NOCTALIA_WALLPAPER_PATH:-}"
    [ -f "$image" ] || exit 0
    # Ignore the applied image, including changes emitted by our own rebuild.
    ${pkgs.diffutils}/bin/cmp -s -- "$image" ${config.stylix.image} && exit 0
    # ponytail: one rebuild at a time; reselect after completion if changed while busy.
    # A separate unit survives the Noctalia restart during Home Manager activation.
    exec ${pkgs.systemd}/bin/systemd-run --user --collect --unit=stylix-wallpaper \
      ${pkgs.foot}/bin/foot --title="Apply wallpaper to Stylix" ${rebuildWallpaper} "$image"
  '';
in
{
  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    settings = {
      shell = {
        launch_apps_as_systemd_services = true;
        setup_wizard_enabled = false;
      };
      wallpaper.enabled = true;
      hooks.wallpaper_changed = toString wallpaperHook;
      # Stylix owns application themes; Noctalia consumes its palette.
      theme.templates = {
        enable_builtin_templates = false;
        enable_community_templates = false;
      };
    };
  };
  stylix.targets.noctalia.enable = true;
}
