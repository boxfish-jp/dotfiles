{ self, ... }:
{
  flake.nixosConfigurations.monitor-server = self.lib.mkHost { hostname = "monitor-server"; };

  flake.nixosModules."host-monitor-server" =
    { lib, ... }:
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

      boot.loader.grub.enable = true;
      boot.loader.grub.device = "/dev/sda";
      boot.loader.grub.useOSProber = true;

      services.atticd = {
        enable = true;
        #   ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64="<openssl genrsa -traditional 4096 | base64 -w0>"
        environmentFile = "/etc/atticd.env";

        settings = {
          listen = "[::]:8080";

          jwt = { };

          storage = {
            type = "local";
            path = "/var/lib/atticd/storage";
          };

          database.url = "postgresql://atticd@127.0.0.1/atticd";
        };
      };

      services.postgresql = {
        enable = true;
        ensureDatabases = [ "atticd" ];
        ensureUsers = [
          {
            name = "atticd";
            ensureDBOwnership = true;
          }
        ];
        authentication = lib.mkForce ''
          local all all trust
          host all all 127.0.0.1/32 trust
          host all all ::1/128 trust
        '';
      };
    };
}
