{ self, ... }:
{
  flake.homeModules.paint =
    {
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [
        krita
      ];
    }

  ;
}
