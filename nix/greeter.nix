{ pkgs, config, vitobar, ... }:
let
  vitobarPkg = vitobar.packages.x86_64-linux.default;

  # vitogreeter runs as the `greeter` user, so it never sees vito's
  # home-manager Stylix theme. It reads colors from $HOME/.config/stylix/palette.json
  # (see vitobar src/config.rs: load_stylix_colors), falling back to built-in
  # defaults when absent — which is why the login screen doesn't match.
  #
  # Replicate vito's Stylix palette from the system-level base16 colors so the
  # greeter matches. Note: palette.json keys base0A–base0F are UPPERCASE (the
  # struct fields are lowercase; serde maps them) and values have no leading '#'.
  c = config.lib.stylix.colors;
  palette = pkgs.writeText "palette.json" (builtins.toJSON {
    inherit (c)
      base00 base01 base02 base03 base04 base05 base06 base07
      base08 base09 base0A base0B base0C base0D base0E base0F;
    scheme = "Everforest Dark Medium";
    slug = "everforest-dark-medium";
  });

  # vitogreeter resolves config via $HOME, so hand it a HOME whose
  # .config/stylix/palette.json is our generated palette.
  greeterHome = pkgs.runCommand "vitogreeter-home" { } ''
    mkdir -p "$out/.config/stylix"
    cp ${palette} "$out/.config/stylix/palette.json"
  '';
in
{
  users.users.greeter.extraGroups = [ "seat" "video" ];

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.coreutils}/bin/env HOME=${greeterHome} ${pkgs.cage}/bin/cage -s -- ${vitobarPkg}/bin/vitogreeter";
        user = "greeter";
      };
    };
  };
}
