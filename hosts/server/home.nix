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
    ../../direnv
    ../../llm
  ];
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "26.11";
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

    streaming-kit-stream-orchestrator = {
      enable = true;
      hubUrl = "http://0.0.0.0:8888";
      tokenDbPath = "${config.home.homeDirectory}/.local/share/streaming-kit/token.db";
      educationDbPath = "${config.home.homeDirectory}/.local/share/streaming-kit/education.db";
      headlessBrowserUrl = "http://0.0.0.0:4321";
      voicepeakPath = "${config.home.homeDirectory}/.local/share/streaming-kit/voicepeak/voicepeak";
      oauthCallbackBaseUrl = "https://nixos-ct.taildb6ca.ts.net:5000";
      systemd.enable = true;
    };
  };

  services.twitch-recorder = {
    enable = true;
    username = "mogra";
    rootPath = "/mnt/iohdd/share/stream_record/";
    environmentFile = "${config.home.homeDirectory}/.config/twitch-recorder/.env";
  };

  programs.home-manager.enable = true;
}
