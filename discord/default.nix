{ self, ... }:
{
  flake.homeModules.discord =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        discord
        concord-tui
      ];
    }

  ;
}
