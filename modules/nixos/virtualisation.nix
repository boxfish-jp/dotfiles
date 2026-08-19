{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.domains.virtualisation;
in
{
  options.domains.virtualisation = {
    podman = mkEnableOption "コンテナ (containers + podman)";
    waydroid = mkEnableOption "Waydroid";
  };

  config = mkMerge [
    (mkIf cfg.podman {
      virtualisation.containers.enable = true;
      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true; # Required for containers under podman-compose to be able to talk to each other.
      };
    })
    (mkIf cfg.waydroid {
      virtualisation.waydroid = {
        enable = true;
        package = pkgs.waydroid-nftables;
      };
    })
  ];
}
