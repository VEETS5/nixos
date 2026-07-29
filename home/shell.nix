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
      # Show an image inline in foot via sixel. `-f sixel` is redundant now that
      # TERM=foot auto-detects, but keeps this working over ssh/tmux/TERM
      # overrides where detection gives up.
      icat = "chafa -f sixel";
    };
    initExtra = ''
      export EDITOR=nvim
      export PATH="$HOME/.local/bin:$PATH"
      macchina --theme nixos

      # foot.ini sets TERM=foot so local image viewers auto-detect sixel, but
      # remote hosts usually have no `foot` terminfo entry and greet you with
      # "unknown terminal type". Downgrade TERM for the remote side only.
      ssh() { TERM=xterm-256color command ssh "$@"; }

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
