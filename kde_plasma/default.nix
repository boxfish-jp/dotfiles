{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    kara
    kdePackages.krohnkite
  ];
  programs.plasma = {
    enable = true;
    configFile = {
      kwinrc = {
        Desktops = {
          Number = 6;
          Rows = 1;
        };
        plugins = {
          krohnkiteEnabled = true;
          virtualdesktopsonlyonprimaryEnabled = true;
        };
        Wayland.InputMethod.value = "/run/current-system/sw/share/applications/org.fcitx.Fcitx5.desktop";
      };
      kxkbrc.Layout.LayoutList = "jp";
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
}
