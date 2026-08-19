{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  proxmoxLXC = {
    manageNetwork = false;
    privileged = true;
  };

  services.fstrim.enable = false; # Let Proxmox host handle fstrim

  systemd.mounts = [
    {
      where = "/sys/kernel/debug";
      enable = false;
    }
  ];
}
