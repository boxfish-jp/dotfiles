{ lib, config, ... }:

let
  cfg = config.wakeOnLan;
in
{
  options.wakeOnLan = {
    enable = lib.mkEnableOption "Wake on LAN (magic packet) on the wired NICs";

    interfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "enp10s0" ];
      description = "Wired NIC interface names to enable Wake on LAN on.";
    };

    udpPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ 9 ];
      example = [
        9
        7
      ];
      description = "UDP ports to open for magic packets (7=echo, 9=discard).";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.interfaces = lib.genAttrs cfg.interfaces (iface: {
      wakeOnLan.enable = true;
    });

    networking.firewall.allowedUDPPorts = cfg.udpPorts;
  };
}
