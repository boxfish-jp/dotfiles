{ self, ... }:
{
  flake.homeModules.other_gui =
    {
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [
        discord
        vlc
        vscode
        google-chrome
      ];
    }

  ;
}
