{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.packages = with pkgs; [
    davinci-resolve
    voicevox
  ];
}
