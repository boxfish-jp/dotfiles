{ config, pkgs, nixgl, system, ... }:
let
  nixGL = nixgl.packages.${system}.nixGLDefault;

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
  kanata-with-cmd = pkgs.kanata.override { withCmd = true; };
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
    yt-dlp
    kanata-with-cmd
  ];

  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  home.sessionPath = [ "$ANDROID_HOME/platform-tools" ];

  programs.vicinae = {
    enable = true;
    systemd = {
      enable = true;
      autoStart = true;
      target = "graphical-session.target";
    };
    package = vicinae-wrapped;
  };

  programs.plasma = {
    enable = true;

    kwin = {
      # 仮想デスクトップ数・配置
      virtualDesktops = {
        number = 4;
        rows = 1;
      };

      # 提供されたショートカットを全て変換・登録
      # plasma-manager はこのセクションのみを kglobalshortcutsrc に書き込みます
    };

    shortcuts = {
      kwin = {
        "Activate Window Demanding Attention" = [ "Meta+Ctrl+A" ];
        "Edit Tiles" = [ "Meta+T" ];
        "Expose" = [ "Meta+F9" "Ctrl+F9" ];
        "ExposeAll" = [ "Launch (C)" "Ctrl+F10" "Meta+F10" ];
        "ExposeClass" = [ "Meta+F7" "Ctrl+F7" ];
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
        "Switch to Desktop 1" = [ "Meta+1" "Ctrl+F1" ];
        "Switch to Desktop 2" = [ "Ctrl+F2" "Meta+2" ];
        "Switch to Desktop 3" = [ "Meta+3" "Ctrl+F3" ];
        "Switch to Desktop 4" = [ "Ctrl+F4" "Meta+4" ];
        
        # ウィンドウ操作
        "Switch Window Down" = [ "Meta+Alt+Down" ];
        "Switch Window Left" = [ "Meta+Alt+Left" ];
        "Switch Window Right" = [ "Meta+Alt+Right" ];
        "Switch Window Up" = [ "Meta+Alt+Up" ];
        "Walk Through Windows" = [ "Alt+Tab" "Meta+Tab" ];
        "Walk Through Windows (Reverse)" = [ "Alt+Shift+Tab" "Meta+Shift+Tab" ];
        "Walk Through Windows of Current Application" = [ "Alt+`" "Meta+`" ];
        "Walk Through Windows of Current Application (Reverse)" = [ "Meta+~" "Alt+~" ];
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
        
        # ウィンドウをデスクトップへ移動（日本語配列の記号）
        "Window to Desktop 1" = [ "Meta+!" ];
        "Window to Desktop 2" = [ "Meta+\"" ];
        "Window to Desktop 3" = [ "Meta+#" ];
        "Window to Desktop 4" = [ "Meta+$" ];
        "Window to Desktop 5" = [ "Meta+%" ];
        "Window to Next Screen" = [ "Meta+Shift+Right" ];
        "Window to Previous Screen" = [ "Meta+Shift+Left" ];
        
        "disableInputCapture" = [ "Meta+Shift+Esc" ];
        "view_actual_size" = [ "Meta+0" ];
        "view_zoom_in" = [ "Meta+=" "Meta++" ];
        "view_zoom_out" = [ "Meta+-" ];
      };
      custom = {
        "net.local.vicinae.desktop" = [ "Henkan" ];
      };
    };
  };

  home.file.".bashrc".source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/.config/home-manager/dotfiles/bashrc";

  xdg.configFile = {
    "nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/dotfiles/nvim";
    "alacritty".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/dotfiles/alacritty";
    "zellij".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/dotfiles/zellij";
    "kanata/kanata.kbd".text = ''
        (defcfg
          process-unmapped-keys yes
          danger-enable-cmd yes
        )

        (defsrc
          caps muhenkan henkan
        )

        (deflayer base
          esc lmet (cmd "vicinae" "toggle")
        )
      '';
  };

  xdg.dataFile = {
    "vicinae/scripts".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/dotfiles/vicinae/scripts";
    "applications/alacritty.desktop".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/dotfiles/applications/alacritty.desktop";
    "icons/alacritty.png".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/dotfiles/icons/alacritty.png";
    "kwin/scripts/krohnkite".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/dotfiles/kde_plasma/kwin/scripts/krohnkite";
  };


  systemd.user.services.kanata = {
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

  programs.home-manager.enable = true;
}
