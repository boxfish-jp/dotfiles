{ self, ... }:
{
  flake.homeModules.other_gui =
    {
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [
        kdePackages.dolphin
        vlc
        vscode
        google-chrome
      ];
    }

  ;
}
