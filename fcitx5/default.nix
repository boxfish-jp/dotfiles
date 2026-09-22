{ self, ... }:
{
  flake.homeModules.fcitx5 =
    {
      ...
    }:
    {
      xdg.configFile."fcitx5/profile".source = ./profile;
    }

  ;
}
