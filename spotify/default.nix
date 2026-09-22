{ self, ... }:
{
  flake.homeModules.spotify =
    {
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [
        spotify
        spotify-player
      ];
    }

  ;
}
