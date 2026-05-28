{
  config,
  pkgs,
  username,
  hostname,
  ...
}:
let

  kanata-with-cmd = pkgs.kanata.override { withCmd = true; };

  gitIdentities = {
    "laptop" = {
      name = "labfish";
      email = "168062620+labFish00@users.noreply.github.com";
    };
    "boxfish" = {
      name = "boxfish_jp";
      email = "79849824+boxfish-jp@users.noreply.github.com";
    };
  };

  currentGit = gitIdentities.${hostname} or gitIdentities."boxfish";
in
{
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";
    packages = with pkgs; [
      firefox
      neovim
      git
      curl
      lazygit
      fzf
      ripgrep
      fd
      wl-clipboard
      gnumake
      pkg-config
      clang
      hackgen-nf-font
      starship
      zellij
      alacritty
      pnpm
      uv
      qpwgraph
      gh
      ffmpeg
      gdb
      cmake
      yt-dlp
      kanata-with-cmd
      discord
      spotify
      ncdu
      vlc
      cargo
      rustc
      krita
      vscode
      google-chrome
      osu-lazer
    ];

    file.".bashrc".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/dotfiles/bashrc";
  };

  systemd.user.services = {
    kanata = {
      Unit = {
        Description = "Kanata keyboard remapper (with cmd)";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${kanata-with-cmd}/bin/kanata --cfg %h/.config/kanata/kanata.kbd";
        Restart = "on-failure";
        RestartSec = "2s";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    qpwgraph = {
      Unit = {
        Description = "PipeWire Graph Qt GUI (qpwgraph)";
        After = [
          "graphical-session.target"
          "pipewire.service"
        ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.qpwgraph}/bin/qpwgraph -m";
        Environment = [
          "WAYLAND_DISPLAY=wayland-0"
          "XDG_RUNTIME_DIR=%t"
        ];
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };

  xdg = {
    configFile = {
      "fcitx5".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/dotfiles/fcitx5";
      "nvim".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/dotfiles/nvim";
      "alacritty".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/dotfiles/alacritty";
      "zellij".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/dotfiles/zellij";
      "kanata".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/dotfiles/kanata";
      "pipewire/pipewire.conf.d/99-virtual-cables.conf".text = ''
        context.objects = [
          { factory = adapter
            args = {
              factory.name     = "support.null-audio-sink"
              node.name        = "default-output"
              node.description = "default"
              media.class      = "Audio/Sink"
            }
          }
          { factory = adapter
            args = {
              factory.name     = "support.null-audio-sink"
              node.name        = "for-obs"
              node.description = "obs always listen"
              media.class      = "Audio/Sink"
            }
          }
        ]
      '';
      "git/config".text = ''
        [user]
          name = ${currentGit.name}
          email = ${currentGit.email}
        [init]
          defaultBranch = main
        [core]
          editor = nvim 
        [credential "https://github.com"]
          helper = 
          helper = !${config.home.homeDirectory}/.nix-profile/bin/gh auth git-credential
      '';

    };

    dataFile = {
      "vicinae/scripts".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/dotfiles/vicinae/scripts";
      "applications/alacritty.desktop".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/dotfiles/applications/alacritty.desktop";
      "icons/alacritty.png".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/dotfiles/icons/alacritty.png";
      "kwin/scripts/krohnkite".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/dotfiles/kde_plasma/kwin/scripts/krohnkite";
    };
  };

  programs = {
    vicinae = {
      enable = true;
      systemd = {
        enable = true;
        autoStart = true;
      };
    };

    streaming-kit-cli = {
      enable = true;

      workDir = "~/dev/";
      serverUrl = "http://192.168.68.11:8888";

      systemd.enable = true;
      systemd.serviceName = "streaming-kit";
    };

    plasma = {
      enable = true;
      kwin = {
        virtualDesktops = {
          number = 6;
          rows = 1;
        };
      };
      shortcuts = {
        kwin = {
          "Activate Window Demanding Attention" = [ "Meta+Ctrl+A" ];
          "Edit Tiles" = [ "Meta+T" ];
          "Expose" = [
            "Meta+F9"
            "Ctrl+F9"
          ];
          "ExposeAll" = [
            "Launch (C)"
            "Ctrl+F10"
            "Meta+F10"
          ];
          "ExposeClass" = [
            "Meta+F7"
            "Ctrl+F7"
          ];
          "Grid View" = [ "Meta+G" ];
          "Kill Window" = [ "Meta+Ctrl+Esc" ];

          # Krohnkite 操作系
          "KrohnkiteFloatAll" = [ "Meta+Shift+F" ];
          "KrohnkiteFocusDown" = [ "Meta+J" ];
          "KrohnkiteFocusLeft" = [ "Meta+H" ];
          "KrohnkiteFocusPrev" = [ "Meta+," ];
          "KrohnkiteFocusRight" = [ "Meta+L" ];
          "KrohnkiteFocusUp" = [ "Meta+K" ];
          "KrohnkiteGrowHeight" = [ "Meta+Ctrl+J" ];
          "KrohnkiteMonocleLayout" = [ "Meta+M" ];
          "KrohnkiteNextLayout" = [ "Meta+\\" ];
          "KrohnkitePreviousLayout" = [ "Meta+|" ];
          "KrohnkiteSetMaster" = [ "Meta+Return" ];
          "KrohnkiteShiftDown" = [ "Meta+Shift+J" ];
          "KrohnkiteShiftLeft" = [ "Meta+Shift+H" ];
          "KrohnkiteShiftRight" = [ "Meta+Shift+L" ];
          "KrohnkiteShiftUp" = [ "Meta+Shift+K" ];
          "KrohnkiteShrinkHeight" = [ "Meta+Ctrl+K" ];
          "KrohnkiteShrinkWidth" = [ "Meta+Ctrl+H" ];
          "KrohnkiteToggleFloat" = [ "Meta+F" ];
          "KrohnkitegrowWidth" = [ "Meta+Ctrl+L" ]; # 出力元の小文字gを維持

          "MoveMouseToCenter" = [ "Meta+F6" ];
          "MoveMouseToFocus" = [ "Meta+F5" ];
          "Overview" = [ "Meta+W" ];
          "Show Desktop" = [ "Meta+D" ];

          # デスクトップ切り替え
          "Switch One Desktop Down" = [ "Meta+Ctrl+Down" ];
          "Switch One Desktop Up" = [ "Meta+Ctrl+Up" ];
          "Switch One Desktop to the Left" = [ "Meta+Ctrl+Left" ];
          "Switch One Desktop to the Right" = [ "Meta+Ctrl+Right" ];
          "Switch to Desktop 1" = [
            "Meta+1"
            "Ctrl+F1"
          ];
          "Switch to Desktop 2" = [
            "Ctrl+F2"
            "Meta+2"
          ];
          "Switch to Desktop 3" = [
            "Meta+3"
            "Ctrl+F3"
          ];
          "Switch to Desktop 4" = [
            "Ctrl+F4"
            "Meta+4"
          ];
          "Switch to Desktop 5" = [
            "Ctrl+F5"
            "Meta+5"
          ];
          "Switch to Desktop 6" = [
            "Ctrl+F6"
            "Meta+6"
          ];

          # ウィンドウ操作
          "Switch Window Down" = [ "Meta+Alt+Down" ];
          "Switch Window Left" = [ "Meta+Alt+Left" ];
          "Switch Window Right" = [ "Meta+Alt+Right" ];
          "Switch Window Up" = [ "Meta+Alt+Up" ];
          "Walk Through Windows" = [
            "Alt+Tab"
            "Meta+Tab"
          ];
          "Walk Through Windows (Reverse)" = [
            "Alt+Shift+Tab"
            "Meta+Shift+Tab"
          ];
          "Walk Through Windows of Current Application" = [
            "Alt+`"
            "Meta+`"
          ];
          "Walk Through Windows of Current Application (Reverse)" = [
            "Meta+~"
            "Alt+~"
          ];
          "Window Close" = [ "Alt+F4" ];
          "Window Maximize" = [ "Meta+PgUp" ];
          "Window Minimize" = [ "Meta+PgDown" ];
          "Window One Desktop Down" = [ "Meta+Ctrl+Shift+Down" ];
          "Window One Desktop Up" = [ "Meta+Ctrl+Shift+Up" ];
          "Window One Desktop to the Left" = [ "Meta+Ctrl+Shift+Left" ];
          "Window One Desktop to the Right" = [ "Meta+Ctrl+Shift+Right" ];
          "Window Operations Menu" = [ "Alt+F3" ];
          "Window Quick Tile Bottom" = [ "Meta+Down" ];
          "Window Quick Tile Left" = [ "Meta+Left" ];
          "Window Quick Tile Right" = [ "Meta+Right" ];
          "Window Quick Tile Top" = [ "Meta+Up" ];

          "Window to Desktop 1" = [ "Meta+!" ];
          "Window to Desktop 2" = [ "Meta+\"" ];
          "Window to Desktop 3" = [ "Meta+#" ];
          "Window to Desktop 4" = [ "Meta+$" ];
          "Window to Desktop 5" = [ "Meta+%" ];
          "Window to Desktop 6" = [ "Meta+&" ];
          "Window to Next Screen" = [ "Meta+Shift+Right" ];
          "Window to Previous Screen" = [ "Meta+Shift+Left" ];

          "disableInputCapture" = [ "Meta+Shift+Esc" ];
          "view_actual_size" = [ "Meta+0" ];
          "view_zoom_in" = [
            "Meta+="
            "Meta++"
          ];
          "view_zoom_out" = [ "Meta+-" ];
        };
        custom = {
          "net.local.vicinae.desktop" = [ "Henkan" ];
        };
      };
    };

    obs-studio = {
      enable = true;
      package = (
        pkgs.obs-studio.override {
          cudaSupport = true;
        }
      );

      plugins = with pkgs.obs-studio-plugins; [
        obs-multi-rtmp
      ];
    };

    home-manager.enable = true;
  };
}
