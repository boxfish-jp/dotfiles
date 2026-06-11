{
  config,
  pkgs,
  lib,
  username,
  hostname,
  ...
}:
{
  imports = [
    ./common-modules
    ./kanata
    ./flatpak
    ./qpwgraph
    ./obs
    ./streaming
    ./vicinae
    ./nvim
    ./kde_plasma
    ./fcitx5
    ./alacritty
    ./pipewire
    ./zellij
    ./git
    ./video_editor
    ./bash
  ];
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
}
