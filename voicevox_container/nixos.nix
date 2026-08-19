{ lib, config, ... }:

let
  cfg = config.services.voicevox_container;
in
{
  options.services.voicevox_container = {
    enable = lib.mkEnableOption "VoiceVox text-to-speech engine container";

    user = lib.mkOption {
      type = lib.types.str;
      default = "boxfish";
      description = "Unix user that runs the container (rootless podman).";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 50021 ];

    users.users.${cfg.user} = {
      subUidRanges = [
        {
          startUid = 100000;
          count = 65536;
        }
      ];

      subGidRanges = [
        {
          startGid = 100000;
          count = 65536;
        }
      ];
    };
  };
}
