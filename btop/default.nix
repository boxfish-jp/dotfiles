{ self, ... }:
{
  flake.homeModules.btop =
    {
      config,
      pkgs,
      ...
    }:
    with pkgs;
    {
      home.packages =
        if config.home.username == "boxfish" then
          [
            btop-cuda
          ]
        else
          [
            btop
          ];
    }

  ;
}
