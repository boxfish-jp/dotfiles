{ self, ... }:
{
  flake.homeModules.zellij =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      home.packages = [
        pkgs.zellij
      ];
      xdg.configFile."zellij".source = ./.;
    }

  ;
}
