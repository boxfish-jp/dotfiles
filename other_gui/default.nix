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
        kdePackages.dolphin
        vlc
        vscode
        google-chrome
      ];
    }

  ;
}
