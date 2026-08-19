# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ ... }:

{
  imports = [
    ../../modules/nixos/lxc.nix
    ../../modules/nixos/locale.nix
    ../../modules/nixos/networking.nix
    ../../modules/nixos/nix.nix
    ../../modules/nixos/user.nix
    ../../modules/nixos/fonts.nix
    ../../modules/nixos/virtualisation.nix
    ../../modules/nixos/ssh.nix
    ../../modules/nixos/certificate.nix
    ../../tailscale/nixos.nix
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
}
