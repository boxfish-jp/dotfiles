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
      voicevoxUrls = "http://boxfish-1.taildb6ca.ts.net:50021,http://127.0.0.1:50021";
      systemd.enable = true;
    };
  };

  programs.home-manager.enable = true;
}
