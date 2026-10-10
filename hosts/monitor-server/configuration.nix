{ self, ... }:
{
  flake.nixosConfigurations.monitor-server = self.lib.mkHost { hostname = "monitor-server"; };

  flake.nixosModules."host-monitor-server" =
    { ... }:
    {
      imports = [
        self.nixosModules.locale
        self.nixosModules.networking
        self.nixosModules.nix
        self.nixosModules.user
        self.nixosModules.fonts
        self.nixosModules.ssh
        self.nixosModules.certificate
        self.nixosModules.tailscale
      ];

      domains = {
        networking.allowedTCPPorts = [
          8080
        ];
      };

      tailscale.enable = true;

      # ベアメタル起動用 (UEFI 前提。実機で nixos-generate-config した
      # hosts/monitor-server/hardware-configuration.nix を laptop と同型で追加すること)
      boot.loader.grub.enable = true;
      boot.loader.grub.device = "/dev/sda";
      boot.loader.grub.useOSProber = true;

      services.atticd = {
        enable = true;
        # /etc/atticd.env は手動配置 (git管理外、chmod 600):
        #   ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64="<openssl genrsa -traditional 4096 | base64 -w0>"
        environmentFile = "/etc/atticd.env";

        settings = {
          listen = "[::]:8080";

          jwt = { };

          storage = {
            type = "local";
            path = "/var/lib/atticd/storage";
          };

          database.url = "sqlite:///var/lib/atticd/server.db?mode=rwc";
        };
      };
    };
}
