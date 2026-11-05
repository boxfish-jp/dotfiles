{ self, ... }:
{
  flake.homeModules."server/server" =
    { config, ... }:
    {
      imports = [
        self.homeModules.containers
        self.homeModules.voicevox_container
        self.homeModules.browser-chan
        self.homeModules.fuguo_api
        self.homeModules.nvim
        self.homeModules.zellij
        self.homeModules.git
        self.homeModules.bash
        self.homeModules.llm
      ];

      home.stateVersion = "26.11";

      services.voicevox_container.enable = true;

      services.browser-chan = {
        enable = true;
        port = 4321;
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
          headlessBrowserUrl = "http://${config.services.browser-chan.host}:${toString config.services.browser-chan.port}";
          voicepeakPath = "${config.home.homeDirectory}/.local/share/streaming-kit/voicepeak/voicepeak";
          oauthCallbackBaseUrl = "http://127.0.0.1:5000";
          systemd.enable = true;
        };
      };

      services.twitch-recorder = {
        enable = true;
        username = "mogra";
        rootPath = "/mnt/iohdd/share/stream_record/";
        environmentFile = "${config.home.homeDirectory}/.config/twitch-recorder/.env";
      };

      services.home-reporter = {
        enable = true;
        environmentFile = "${config.home.homeDirectory}/.config/home-reporter/.env";
        streamingKitHubUrl = "http://192.168.68.16:8888";
      };

      programs.home-manager.enable = true;
    };
}
