{
  pkgs,
  ...
}:

let
  playit = pkgs.callPackage ./playit.nix { };
in
{
  environment.systemPackages = [ playit ];

  virtualisation.oci-containers.containers.palworld = {
    image = "thijsvanloef/palworld-server-docker";
    autoStart = true;
    environmentFiles = [ "/home/game/.config/palworld/.env" ];
    ports = [ "8211:8211/udp" "27015:27015/udp" ];
    volumes = [ "/var/lib/palworld:/palworld" ];
    extraOptions = [ "--pull=always" ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/palworld 0755 1000 1000 -"
  ];

  systemd.services.playit = {
    description = "playit.gg tunneling agent";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${playit}/bin/playit";
      Restart = "always";
      RestartSec = "5s";
      RuntimeDirectory = "playit";
    };
  };
}
