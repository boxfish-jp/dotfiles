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
    ../../nvim
    ../../zellij
    ../../git
    ../../bash
  ];
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "26.11";
  };

  programs.home-manager.enable = true;
}
