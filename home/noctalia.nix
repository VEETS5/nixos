{ ... }:
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
      # Stylix owns application themes; Noctalia consumes its palette.
      theme.templates = {
        enable_builtin_templates = false;
        enable_community_templates = false;
      };
    };
  };
  stylix.targets.noctalia.enable = true;
}
