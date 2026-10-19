{ self, ... }:
{
  flake.nixosConfigurations.game = self.lib.mkHost { hostname = "game"; };

  flake.nixosModules."host-game" =
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
        self.nixosModules.palworld
      ];

      domains = {
        networking.allowedTCPPorts = [ ];
        nix = {
          sandbox = false;
          maxJobs = 4;
        };
        virtualisation.podman = true;
        ssh.rootLogin = true;
      };
    };
}
