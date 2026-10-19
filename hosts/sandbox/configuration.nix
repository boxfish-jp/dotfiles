{ self, ... }:
{
  flake.nixosConfigurations.sandbox = self.lib.mkHost { hostname = "sandbox"; };

  flake.nixosModules."host-sandbox" =
    { ... }:
    {
      imports = [
        self.nixosModules.lxc
        self.nixosModules.locale
        self.nixosModules.networking
        self.nixosModules.nix
        self.nixosModules.user
        self.nixosModules.fonts
        self.nixosModules.virtualisation
        self.nixosModules.ssh
        self.nixosModules.certificate
        self.nixosModules.tailscale
      ];

      domains = {
        networking.allowedTCPPorts = [ ];
        nix = {
          sandbox = false;
          maxJobs = 4;
        };
        virtualisation.podman = true;
        ssh.rootLogin = true;
        users.linger = true;
      };

      tailscale.enable = true;
    };
}
