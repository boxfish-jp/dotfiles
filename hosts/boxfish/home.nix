{
  config,
  pkgs,
  lib,
  username,
  ...
}:
{
  imports = [
    ../../containers
    ../../kanata
    ../../flatpak
    ../../qpwgraph
    ../../obs
    ../../streaming
    ../../vicinae
    ../../nvim
    ../../kde_plasma
    ../../fcitx5
    ../../alacritty
    ../../pipewire
    ../../zellij
    ../../git
    ../../video_editor
    ../../bash
    ../../llm
    ../../paint
    ../../other_cli
    ../../other_gui
  ];
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
}
