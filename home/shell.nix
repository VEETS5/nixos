{ config, pkgs, ... }:
{
  programs.bash = {
    enable = true;
    shellAliases = {
      ll   = "ls -la";
      cls  = "clear";
      snvim = "sudo -E nvim";
      ni = "cd ~/.config/nixos/";
      vbu = "bash ~/.config/nixos/update-vitobar.sh";
      wp  = "bash ~/.config/nixos/set-wallpaper.sh";
      ncp = "cd ~/.config/nixos && git add -A && git commit && git push && cd -";
      claude-latest = "$HOME/.local/bin/claude";
    };
    initExtra = ''
      export EDITOR=nvim
      export PATH="$HOME/.local/bin:$PATH"
      macchina --theme nixos

      # nixos-rebuild aliases, guarded by hostname so running the wrong one
      # on the wrong machine (e.g. nrd on nixpad) refuses instead of
      # switching this host onto the other machine's hardware config.
      _nr_guarded() {
        local host="$1" flakehost="$2"; shift 2
        if [ "$(hostname)" != "$host" ]; then
          echo "refusing: this is $(hostname), not $host (use the alias for this machine instead)" >&2
          return 1
        fi
        "$@" --flake "$HOME/.config/nixos#$flakehost"
      }
      nrl() { _nr_guarded nixpad nixpad sudo nixos-rebuild switch; }
      nrd() { _nr_guarded nixtop nixtop sudo nixos-rebuild switch; }
      npl() { git -C ~/.config/nixos pull && _nr_guarded nixpad nixpad sudo nixos-rebuild switch; }
    '';
  };
}
