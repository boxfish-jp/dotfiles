{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    discord
    spotify
    vlc
    vscode
    google-chrome
  ];
}
