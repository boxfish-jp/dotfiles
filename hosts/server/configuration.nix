# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  modulesPath,
  pkgs,
  hostname,
  username,
  ...
}:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../../tailscale/nixos.nix
    ../../voicevox_container/nixos.nix
  ];
  nix.settings = {
    sandbox = false;
  };
  proxmoxLXC = {
    manageNetwork = false;
    privileged = true;
  };
  services.fstrim.enable = false; # Let Proxmox host handle fstrim
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      PermitEmptyPasswords = "yes";
    };
  };

  networking.hostName = hostname;

  time.timeZone = "Asia/Tokyo";

  # Select internationalisation properties.

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  #services.xserver.enable = true;
  tailscale.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [
      "networkmanager"
      "wheel"
      "podman"
      "samba"
    ];
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    max-jobs = 4;
    trusted-users = [ username ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
    # neovim
  ];

  virtualisation = {
    containers.enable = true;

    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true; # Required for containers under podman-compose to be able to talk to each other.
    };
  };

  services.voicevox_container = {
    enable = true;
    user = "server";
  };

  systemd.mounts = [
    {
      where = "/sys/kernel/debug";
      enable = false;
    }
  ];

  fonts = {
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      hackgen-nf-font
    ];
    fontDir.enable = true;
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

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

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  security.pki.certificateFiles = [
    ../../certificate/pve-root-ca.pem
  ];
  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  networking.firewall.allowedTCPPorts = [
    5000
    8888
    50020
  ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.11"; # Did you read the comment?

}
