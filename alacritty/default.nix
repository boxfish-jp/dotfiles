{ self, ... }:
{
  flake.homeModules.alacritty =
    {
      config,
      pkgs,
      lib,
      hostname,
      ...
    }:
    {
      home.packages = [
        pkgs.alacritty
      ];

      xdg.configFile."alacritty".source = ./.;
    }

  ;
}
