{ pkgs, ... }:
{
  programs.nixcord = {
    enable = true;
    vesktop = {
      enable = true;
      # WebRTC must not bind voice sockets to the tailscale0 address, or Discord
      # voice hangs at "DTLS connecting" (handshake over an unroutable 100.x src).
      # The --force-webrtc-ip-handling-policy CLI switch no longer exists in
      # Electron 40, so the policy has to be set via the webContents API.
      package = pkgs.vesktop.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace src/main/mainWindow.ts --replace-fail \
            'win.webContents.setUserAgent(BrowserUserAgent);' \
            'win.webContents.setUserAgent(BrowserUserAgent);
            win.webContents.setWebRTCIPHandlingPolicy("default_public_interface_only");'
        '';
      });
    };

    config = {
      frameless = true;
      plugins = {
        hideMedia.enable = true;
        ignoreActivities = {
          enable = true;
          ignorePlaying = true;
          ignoredActivities = [];
        };
      };
    };
  };
}
