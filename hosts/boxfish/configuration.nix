{ self, ... }:
{
  flake.nixosConfigurations.boxfish = self.lib.mkHost { hostname = "boxfish"; };

  flake.nixosModules."host-boxfish" =
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
        self.nixosModules.ssh
        self.nixosModules.certificate
        self.nixosModules.tailscale
        self.nixosModules.voicevox_container
        self.nixosModules.wake_on_lan
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

      # noauto + x-systemd.automount + nofail: boot never blocks on the NAS;
      # the mount is established on first access to /mnt/nas and kept until reboot.
      # If the NAS is unreachable, access to /mnt/nas fails after a short timeout.
      fileSystems."/mnt/nas" = {
        device = "//192.168.68.16/iohdd";
        fsType = "cifs";
        options = [
          "x-systemd.automount"
          "noauto"
          "nofail"
          "_netdev"
          "x-systemd.device-timeout=5s"
          "x-systemd.mount-timeout=5s"
          "credentials=/etc/samba/credentials.nas"
          "hard"
          "uid=1000"
          "gid=100"
          "forceuid"
          "forcegid"
          "file_mode=0660"
          "dir_mode=0770"
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
        cifs-utils
      ];
    };
}
