{
  flake.nixosModules."host-monitor-server" =
    {
      config,
      lib,
      modulesPath,
      ...
    }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      boot.initrd.availableKernelModules = [
        "ehci_pci"
        "ahci"
        "usb_storage"
        "sd_mod"
        "sr_mod"
      ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ "kvm-intel" ];
      boot.extraModulePackages = [ ];

      fileSystems."/" = {
        device = "/dev/disk/by-uuid/7db5ae5a-7226-4529-aad8-0aa2d606b87c";
        fsType = "ext4";
      };

      swapDevices = [
        { device = "/dev/disk/by-uuid/a220a852-89ae-45d3-9874-13e651cef027"; }
      ];

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
