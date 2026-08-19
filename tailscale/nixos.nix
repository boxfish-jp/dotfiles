{ lib, config, ... }:

let
  cfg = config.tailscale;
in
{
  options.tailscale = {
    enable = lib.mkEnableOption "Tailscale (Mesh VPN) with nftables firewall integration";
  };

  config = lib.mkIf cfg.enable {
    services.tailscale.enable = true;
    networking.nftables.enable = true;
    networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];
    networking.firewall.allowedUDPPorts = [ config.services.tailscale.port ];
    systemd.services.tailscaled.serviceConfig.Environment = [
      "TS_DEBUG_FIREWALL_MODE=nftables"
    ];
  };
}
