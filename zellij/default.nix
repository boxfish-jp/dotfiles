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
