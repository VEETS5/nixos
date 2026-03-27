{ pkgs,  ... }:
{
  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

    image = ../wallpaper/default.png;

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
    };
  };
}
