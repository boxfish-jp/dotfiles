{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.services.voicevox_container;

  image =
    if cfg.gpu == "nvidia" then
      "voicevox/voicevox_engine:nvidia-ubuntu20.04-latest"
    else
      "voicevox/voicevox_engine:cpu-latest";

  runArgs = lib.concatStringsSep " " (
    [
      "run"
      "--name voicevox"
      "--replace"
      "--rm"
      "--pull=always"
      "-p 50021:50021"
    ]
    ++ lib.optionals (cfg.gpu == "nvidia") [
      "--device nvidia.com/gpu=all"
    ]
    ++ [ image ]
  );
in
{
  options.services.voicevox_container = {
    enable = lib.mkEnableOption "VoiceVox text-to-speech engine container";

    gpu = lib.mkOption {
      type = lib.types.enum [
        "nvidia"
        "cpu"
      ];
      default = "cpu";
      description = "GPU backend to use for the VoiceVox engine.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.voicevox = {
      Unit = {
        Description = "VoiceVox text-to-speech engine container (rootless)";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.podman}/bin/podman ${runArgs}";
        ExecStop = "${pkgs.podman}/bin/podman stop voicevox";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
