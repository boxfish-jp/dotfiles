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
    ../../voicevox_container/nixos.nix
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
}
