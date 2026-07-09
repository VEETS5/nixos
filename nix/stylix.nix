{ pkgs, wallpaper, ... }:
{
  stylix = {
    enable = true;
    # No base16Scheme pinned: stylix generates the palette from the wallpaper,
    # so the colorscheme always matches the image. To pin a scheme instead:
    #   base16Scheme = "${pkgs.base16-schemes}/share/themes/ocean.yaml";
    polarity = "dark";

    image = wallpaper;

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name    = "JetBrainsMono Nerd Font";
      };
      sansSerif = {
        package = pkgs.noto-fonts;
        name    = "Noto Sans";
      };
      serif = {
        package = pkgs.noto-fonts;
        name    = "Noto Serif";
      };
      sizes = {
        terminal     = 11;
        applications = 11;
        desktop      = 11;
      };
    };

    cursor = {
      package = pkgs.bibata-cursors;
      name    = "Bibata-Modern-Classic";
      size    = 24;
    };

    targets = {
      gtk.enable = true;
      grub.enable = false;
      kmscon.enable = false;
    };
  };
}
