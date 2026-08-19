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
    ../../modules/nixos/ssh.nix
    ../../modules/nixos/certificate.nix
    ../../tailscale/nixos.nix
    ../../voicevox_container/nixos.nix
    ../../wake_on_lan/nixos.nix
  ];

  domains = {
    locale.japanese = true;
    networking.desktop = true;
    nix.maxJobs = 8;
    virtualisation.podman = true;
    graphics.nvidia = true;
    fonts.defaultFonts = true;
    users.extraGroups = [
      "networkmanager"
      "wheel"
      "podman"
      "input"
    ];
  };

  tailscale.enable = true;

  fileSystems."/mnt/ext4-ssd" = {
    device = "/dev/disk/by-uuid/a5409329-4ec1-46a7-8966-b61994048e9a";
    fsType = "ext4";
    options = [
      "users"
      "nofail"
      "exec"
    ];
  };

  fileSystems."/mnt/windows" = {
    device = "/dev/disk/by-uuid/C49E52179E5201FA";
    fsType = "ntfs3";
    options = [
      "users"
      "nofail"
      "exec"
      "uid=1000"
      "gid=100"
      "umask=022"
    ];
  };

  fileSystems."/home/boxfish/.local/share/Steam/steamapps" = {
    depends = [
      # The mounts above have to be mounted in this given order
      "/"
      "/mnt/ext4-ssd"
    ];
    device = "/mnt/ext4-ssd/steamapps";
    fsType = "none";
    options = [
      "bind"
    ];
  };

  fileSystems."/mnt/windows/steam/steamapps/compatdata" = {
    depends = [
      # The mounts above have to be mounted in this given order
      "/"
      "/mnt/ext4-ssd"
      "/mnt/windows"
    ];
    device = "/mnt/ext4-ssd/steamapps/compatdata";
    fsType = "none";
    options = [
      "bind"
    ];
  };

  services.voicevox_container = {
    enable = true;
    user = "boxfish";
  };

  wakeOnLan = {
    enable = true;
    interfaces = [ "enp10s0" ];
    udpPorts = [ 9 ];
  };

  programs.steam.enable = true;
  services.flatpak.enable = true;

  # List packages installed in system profile.
  environment.systemPackages = with pkgs; [
    qemu
    quickemu
    usbutils
  ];
}
