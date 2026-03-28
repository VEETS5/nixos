{ ... }:
{
  programs.nixcord = {
    enable = true;
    vesktop.enable = true;

    config = {
      frameless = true;
      plugins = {
        hideAttachments.enable = true;
        ignoreActivities = {
          enable = true;
          ignorePlaying = true;
          ignoredActivities = [
          ];
        };
      };
    };
  };
}
