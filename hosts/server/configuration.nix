{ self, ... }:
{
  flake.nixosConfigurations.server = self.lib.mkHost { hostname = "server"; };

  flake.nixosModules."host-server" =
    { lib, ... }:
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
        self.nixosModules.voicevox_container
      ];

      domains = {
        networking.allowedTCPPorts = [
          5000
          8888
          50020
        ];
        nix = {
          sandbox = false;
          maxJobs = 4;
        };
        virtualisation.podman = true;
        ssh.rootLogin = true;
        users.extraGroups = [
          "networkmanager"
          "wheel"
          "podman"
          "samba"
        ];
      };

      tailscale.enable = true;

      # LXC非特権での pam_setcred 失敗回避 (192.168.68.16 Connection reset by peer)
      # nixos/ssh.nix の UsePAM yes をホスト限定で上書き
      services.openssh.settings = {
        UsePAM = lib.mkForce false;
        KbdInteractiveAuthentication = lib.mkForce false;
        PermitEmptyPasswords = lib.mkForce false;
      };

      services.voicevox_container = {
        enable = true;
        user = "server";
      };

      services = {
        samba = {
          enable = true;
          openFirewall = true;

          settings = {
            global = {
              "workgroup" = "WORKGROUP";
              "security" = "user";
              "server string" = "NixOS Samba";
            };

            "iohdd" = {
              "path" = "/mnt/iohdd";
              "browseable" = "yes";
              "read only" = "no";
              "guest ok" = "no";
              "create mask" = "0666";
              "directory mask" = "0777";
            };
          };
        };

        samba-wsdd = {
          enable = true;
          openFirewall = true;
        };

        audiobookshelf = {
          enable = true;
          host = "0.0.0.0";
          port = 13378;
          openFirewall = true;
        };

        adguardhome = {
          enable = true;
          host = "0.0.0.0";
          port = 4003;
          openFirewall = true;
          settings = {
            dns = {
              upstream_dns = [
                "tls://9.9.9.9"
                "tls://1.1.1.1"
              ];
            };
            filtering = {
              protection_enabled = true;
              filtering_enabled = true;

              parental_enabled = false;
              safe_search = {
                enabled = false;
              };
            };
            filters =
              map
                (url: {
                  enabled = true;
                  url = url;
                })
                [
                  "https://github.com/milleruk/adguard-filter-list/blob/main/blocklist?raw=true"
                ];
          };
        };

        resolved.settings.Resolve.DNSStubListener = "no";

        immich = {
          enable = true;
          host = "0.0.0.0";
          port = 2283;
          openFirewall = true;

          mediaLocation = "/mnt/iohdd/share/immich";
        };

        browser-tyan = {
          enable = true;
          port = 4321;
          openFirewall = true;
        };
      };
    };
}
