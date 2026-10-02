{ config, ... }:
let
  colors = config.lib.stylix.colors.withHashtag;
in
{
  # greetd's login environment replaces service-level XDG_DATA_DIRS.
  # Noctalia also searches this directory directly, without that variable.
  environment.pathsToLink = [ "/share/wayland-sessions" ];

  services.displayManager.noctalia-greeter = {
    enable = true;
    cursorTheme = {
      inherit (config.stylix.cursor) package name;
    };
    settings = {
      session.default = "Niri";
      user.default = "vito";
      keyboard.layout = "us";
      cursor.size = config.stylix.cursor.size;
      appearance = {
        scheme = "Synced";
        theme_mode = "dark";
        font_family = config.stylix.fonts.sansSerif.name;
        wallpaper.path = toString config.stylix.image;
        # Same Base16 mapping as Stylix's Noctalia target.
        palette = with colors; {
          primary = base0D;
          on_primary = base00;
          secondary = base0E;
          on_secondary = base00;
          tertiary = base0C;
          on_tertiary = base00;
          error = base08;
          on_error = base00;
          surface = base00;
          on_surface = base05;
          surface_variant = base01;
          on_surface_variant = base04;
          outline = base03;
          shadow = base00;
          hover = base0C;
          on_hover = base00;
        };
      };
    };
  };
}
