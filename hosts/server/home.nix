{
  config,
  pkgs,
  lib,
  username,
  ...
}:
{
  imports = [
    ../../nvim
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

  programs = {
    streaming-kit-hub = {
      enable = true;
      systemd.enable = true;
    };

    streaming-kit-voicevox-connector = {
      enable = true;
      systemd.enable = true;
    };
  };

  programs.home-manager.enable = true;
}
