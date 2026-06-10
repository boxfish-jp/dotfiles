{
  config,
  pkgs,
  lib,
  username,
  hostname,
  ...
}:
let
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
  imports = [
    ./kanata
    ./flatpak
    ./qpwgraph
    ./obs
    ./streaming
    ./vicinae
    ./nvim
    ./kde_plasma
  ];
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";
    packages = with pkgs; [
      firefox
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
      discord
      spotify
      ncdu
      vlc
      cargo
      rustc
      krita
      vscode
      google-chrome
      davinci-resolve
      podman-compose
      nodejs_24
      voicevox
    ];

    file.".bashrc".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/dotfiles/bashrc";
  };


  xdg = {
    configFile = {
      "fcitx5".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/dotfiles/fcitx5";
      "alacritty".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/dotfiles/alacritty";
      "zellij".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/dotfiles/zellij";
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
          helper = !${lib.getExe pkgs.gh} auth git-credential
      '';

    };

    dataFile = {
      "applications/alacritty.desktop".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/dotfiles/applications/alacritty.desktop";
      "icons/alacritty.png".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/dotfiles/icons/alacritty.png";
    };
  };

  programs.home-manager.enable = true;
}
