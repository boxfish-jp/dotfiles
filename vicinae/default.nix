{ config, pkgs, ... }:
{
  programs.vicinae = {
    enable = true;
    systemd = {
      enable = true;
      autoStart = true;
    };
  };
  xdg.dataFile = {
    "vicinae/scripts".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/vicinae/scripts";
  };
}
