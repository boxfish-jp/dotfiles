{ self, ... }:
{
  flake.homeModules.video_editor =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      home.packages = with pkgs; [
        davinci-resolve
        voicevox
      ];
    }

  ;
}
