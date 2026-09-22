{ self, ... }:
{
  flake.nixosModules.desktop = { config, lib, ... }: {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    services.xserver.enable = true;
    services.displayManager.sddm.enable = true;
    services.desktopManager.plasma6.enable = true;
  };

  flake.vmTests.desktop.modules = [ self.nixosModules.desktop ];
}
