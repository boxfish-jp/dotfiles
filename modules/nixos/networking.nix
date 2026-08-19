{
  config,
  lib,
  hostname,
  ...
}:

with lib;

let
  cfg = config.domains.networking;
in
{
  options.domains.networking = {
    desktop = mkEnableOption "デスクトップ向けネットワーク (NetworkManager, nftables, wait-online 無効化)";
    allowedTCPPorts = mkOption {
      type = types.listOf types.port;
      default = [ ];
    };
  };

  config = mkMerge [
    {
      networking.hostName = hostname;
      networking.firewall.allowedTCPPorts = cfg.allowedTCPPorts;
    }
    (mkIf cfg.desktop {
      networking = {
        networkmanager.enable = true;
        nftables.enable = true;
        firewall.enable = true;
      };
      systemd.network.wait-online.enable = false;
      boot.initrd.systemd.network.wait-online.enable = false;
    })
  ];
}
