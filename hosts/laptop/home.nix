{
  config,
  pkgs,
  lib,
  username,
  ...
}:
{
  imports = [
    ../../common-modules
    ../../kanata
    ../../flatpak
    ../../qpwgraph
    ../../obs
    ../../vicinae
    ../../nvim
    ../../kde_plasma
    ../../fcitx5
    ../../alacritty
    ../../zellij
    ../../git
    ../../bash
    ../../llm
  ];
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
}
