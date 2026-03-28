{ ... }:
{
  programs.nixcord = {
    enable = true;
    vesktop.enable = true;
    config = {
      frameless = true;
      plugins = {
        hideAttachments.enable = true;
        noTrack.enable = true;
        clearURLs.enable = true;
        fixCodeblockGap.enable = true;
        gameActivityToggle.enable = true;
        messageLogger.enable = true;
        platformIndicators.enable = true;
        reverseImageSearch.enable = true;
        showHiddenChannels.enable = true;
        showHiddenThings.enable = true;
        betterRoleContext.enable = true;
        memberCount.enable = true;
        mentionAvatars.enable = true;
      };
    };
  };
}
