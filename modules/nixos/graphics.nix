{ config, lib, ... }:

with lib;

let
  cfg = config.domains.graphics;
in
{
  options.domains.graphics = {
    nvidia = mkEnableOption "NVIDIA GPU 設定 (open, modesetting, powerManagement, container-toolkit)";
  };

  config = mkMerge [
    {
      hardware.graphics.enable = true;
    }
    (mkIf cfg.nvidia {
      hardware.nvidia-container-toolkit.enable = true;
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia = {
        open = true;
        modesetting.enable = true;
        powerManagement.enable = true;
      };
    })
  ];
}
