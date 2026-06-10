{
  config,
  pkgs,
  lib,
  ...
}:
{
  xdg.configFile."fcitx5".source = ./.;
}
