# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/nixos/locale.nix
    ../../modules/nixos/keyboard.nix
    ../../modules/nixos/networking.nix
    ../../modules/nixos/nix.nix
    ../../modules/nixos/user.nix
    ../../modules/nixos/fonts.nix
    ../../modules/nixos/virtualisation.nix
    ../../modules/nixos/graphics.nix
    ../../modules/nixos/audio.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/certificate.nix
    ../../tailscale/nixos.nix
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
    drivers = with pkgs; [ canon-cups-ufr2 ];
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
}
