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
  ];
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";

    file.".bashrc".source = ./bashrc;
  };

  programs.home-manager.enable = true;
}
