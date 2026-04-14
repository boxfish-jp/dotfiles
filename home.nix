{ config, pkgs, nixgl, system, ... }:

let
  # nixGLDefault: Intel/AMD/Nouveau 用、または NVIDIA 検出時にフォールバック
  nixGL = nixgl.packages.${system}.nixGLDefault;

  # GPU ドライバを透過的に参照するラッパーを作成
  alacritty-wrapped = pkgs.writeShellScriptBin "alacritty" ''
    exec ${nixGL}/bin/nixGL ${pkgs.alacritty}/bin/alacritty "$@"
  '';

  vicinae-wrapped = pkgs.writeShellScriptBin "vicinae" ''
    exec ${nixGL}/bin/nixGL ${pkgs.vicinae}/bin/vicinae "$@"
  '';

  ffmpeg-wrapped = pkgs.writeShellScriptBin "ffmpeg" ''
    exec ${nixGL}/bin/nixGL ${pkgs.ffmpeg.override {
      withVaapi = true;
      withVpl = true;
    }}/bin/ffmpeg "$@"
  '';
in
{
  home.username = "laptop";
  home.homeDirectory = "/home/laptop";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    neovim git curl lazygit fzf ripgrep fd wl-clipboard
    gnumake pkg-config clang hackgen-nf-font
    starship zellij
    alacritty-wrapped
    pnpm
    uv
    podman
    qpwgraph
    gh
    ffmpeg-wrapped
    gdb
    cmake
  ];

  programs.vicinae = {
    enable = true;
    
    systemd = {
      enable = true;
      autoStart = true;
      target = "graphical-session.target";
    };
    
    #useLayerShell = true;
    
    package = vicinae-wrapped;
  };

  home.file.".bashrc".source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/.config/home-manager/dotfiles/bashrc";

  xdg.configFile = {
    "nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/dotfiles/nvim";
    "alacritty".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/dotfiles/alacritty";
    "zellij".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/dotfiles/zellij";
  };

  xdg.dataFile = {
      "vicinae/scripts".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/dotfiles/vicinae/scripts";
      "applications/alacritty.desktop".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/dotfiles/applications/alacritty.desktop";
      "icons/alacritty.png".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/dotfiles/icons/alacritty.png";

  };

  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    # NVIDIA 利用時のみ有効化
    # __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    # NVD_BACKEND = "direct";
  };

  programs.home-manager.enable = true;
}

