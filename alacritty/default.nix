{
  config,
  pkgs,
  lib,
  username,
  hostname,
  ...
}:
{
  home.packages = [
    pkgs.alacritty
  ];

  xdg.configFile."alacritty".source = ./.;
}
