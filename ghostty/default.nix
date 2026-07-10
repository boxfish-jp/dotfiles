{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.packages = [
    pkgs.ghostty
  ];

  xdg.configFile."ghostty".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/ghostty";
}
