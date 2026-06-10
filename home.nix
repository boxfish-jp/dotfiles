{
  config,
  pkgs,
  lib,
  username,
  hostname,
  ...
}:
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
    ./fcitx5
    ./alacritty
    ./pipewire
    ./git
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

    file.".bashrc".source = ./bashrc;
  };

  programs.home-manager.enable = true;
}
