{ self, ... }:
{
  flake.nixosConfigurations.laptop = self.lib.mkHost { hostname = "laptop"; };

  flake.nixosModules."host-laptop" =
    { pkgs, ... }:
    {
      imports = [
        self.nixosModules.locale
        self.nixosModules.keyboard
        self.nixosModules.networking
        self.nixosModules.nix
        self.nixosModules.user
        self.nixosModules.fonts
        self.nixosModules.virtualisation
        self.nixosModules.graphics
        self.nixosModules.audio
        self.nixosModules.desktop
        self.nixosModules.certificate
        self.nixosModules.tailscale
      ];

      domains = {
        locale.japanese = true;
        networking.desktop = true;
        virtualisation = {
          podman = true;
          waydroid = true;
        };
        fonts.defaultFonts = true;
        users.extraGroups = [
          "networkmanager"
          "wheel"
          "podman"
          "input"
        ];
      };

      tailscale.enable = true;

      hardware.bluetooth = {
        enable = true;
        powerOnBoot = false;
      };

      # Enable CUPS to print documents.
      services.printing = {
        enable = true;
        drivers = with pkgs; [
          canon-cups-ufr2
        ];
      };

      services.avahi = {
        enable = true;
        publish = {
          enable = true;
          userServices = true;
        };
        nssmdns4 = true;
        openFirewall = true;
      };

      services.fprintd.enable = true;

      programs.steam.enable = true;
      services.flatpak.enable = true;

      # List packages installed in system profile.
      environment.systemPackages = with pkgs; [
        qemu
        quickemu
        usbutils
      ];
    };
}
