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
    scheme = "Stylix (wallpaper-generated)";
    slug = "stylix-wallpaper";
  });

  # vitogreeter resolves config via $HOME, so hand it a HOME whose
  # .config/stylix/palette.json is our generated palette.
  greeterHome = pkgs.runCommand "vitogreeter-home" { } ''
    mkdir -p "$out/.config/stylix"
    cp ${palette} "$out/.config/stylix/palette.json"
  '';

  # vitogreeter draws itself as a wlr-layer-shell surface (src/greeter/main.rs binds
  # zwlr_layer_shell_v1 with .expect("layer shell")). cage is a kiosk compositor with
  # no layer-shell, so under cage the greeter panics with "layer shell: NotPresent" at
  # startup and greetd crash-loops. Host it under niri instead — this system's actual
  # compositor, which implements layer-shell. (cage worked only until vitobar's greeter
  # switched from xdg-shell to a layer surface.)
  #
  # Unlike cage, niri does not exit when a spawned child exits, so the wrapper quits niri
  # once vitogreeter returns. This reproduces cage's semantics for both paths: a
  # successful login (vitogreeter exits → niri quits → greetd starts the user session)
  # and a crash (greeter exits → greetd restarts it).
  niriPkg = config.programs.niri.package;
  niriGreeterConfig = pkgs.writeText "niri-greeter.kdl" ''
    spawn-at-startup "${pkgs.bash}/bin/bash" "-c" "${vitobarPkg}/bin/vitogreeter; ${niriPkg}/bin/niri msg action quit --skip-confirmation"

    prefer-no-csd

    hotkey-overlay {
        skip-at-startup
    }
  '';
in
{
  users.users.greeter.extraGroups = [ "seat" "video" ];

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.coreutils}/bin/env HOME=${greeterHome} ${niriPkg}/bin/niri -c ${niriGreeterConfig}";
        user = "greeter";
      };
    };
  };
}
