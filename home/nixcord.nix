{ pkgs, ... }:
{
  programs.nixcord = {
    enable = true;
    vesktop = {
      enable = true;
      useSystemVencord = true;
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

        # ── QoL ─────────────────────────────────────────────────────────────
        volumeBooster = {             # user volume slider goes past 200%
          enable = true;
          multiplier = 2.0;
        };
        messageLogger.enable = true;              # keep deleted/edited messages visible
        callTimer.enable = true;                  # how long you've been in a call
        clearUrls.enable = true;                  # strip tracking params from links you send
        platformIndicators.enable = true;         # desktop/mobile/web status icons
        typingIndicator.enable = true;            # see who's typing in channel list
        typingTweaks.enable = true;               # colored names/avatars in "x is typing"
        showMeYourName.enable = true;             # show username next to nickname
        betterSettings.enable = true;             # faster settings, categories in context menu
        fixImagesQuality.enable = true;           # load full-quality images
        imageZoom.enable = true;                  # magnifier lens on images
        memberCount.enable = true;                # online/total counts
        permissionsViewer.enable = true;          # see who has which permissions
        whoReacted.enable = true;                 # avatars of reactors on reactions
        reverseImageSearch.enable = true;         # right-click image → reverse search
        readAllNotificationsButton.enable = true; # one click mark-all-read
        userVoiceShow.enable = true;              # see which VC someone is in
        voiceDownload.enable = true;              # download button on voice messages
        noF1.enable = true;                       # F1 no longer opens help page
      };
    };
  };
}
