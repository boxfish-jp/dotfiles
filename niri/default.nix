{ self, ... }:
{
  flake.wrappers.desktop =
    {
      wlib,
      pkgs,
      lib,
      ...
    }:
    let
      terminal = self.packages.${pkgs.system}.terminal;
    in
    {
      imports = [ wlib.wrapperModules.niri ];

      settings = {
        spawn-at-startup = [ (lib.getExe pkgs.noctalia) ];

        # SDDM 経由では fcitx5 の user service が起動済みのためガードする。
        spawn-sh-at-startup = [ "pgrep -x fcitx5 || fcitx5 -d" ];

        xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;

        input.keyboard.xkb.layout = "jp";

        # niri は input.touchpad の未記述フラグを明示的に無効化する
        input.touchpad = {
          tap = _: { };
          natural-scroll = _: { };
          drag = true;
          dwt = _: { };
          click-method = "clickfinger";
        };

        outputs = {
          "HDMI-A-1" = {
            mode = "1920x1080@59.934";
            scale = 1.0;
            transform = "normal";
            position = _: {
              props = {
                x = 1920;
                y = 0;
              };
            };
          };
          "eDP-1" = {
            mode = "1920x1080@60.049";
            scale = 1.25;
            transform = "normal";
            position = _: {
              props = {
                x = 3840;
                y = 0;
              };
            };
          };
        };

        layout = {
          gaps = 5;

          # リングは背景ベタ描画され ghostty の透過背景に滲むので廃止し、border で細い枠線だけ描く。
          focus-ring = {
            off = _: { };
          };

          border = {
            width = 2;
            active-color = "#7fc8ff";
            inactive-color = "#3c4048";
          };
        };

        # border も既定は背景ベタ描画。枠線描画に強制して透過中に滲まないようにする。
        window-rules = [
          { draw-border-with-background = false; }

          {
            geometry-corner-radius = 20;
            clip-to-geometry = true;
          }

          {
            # match は props 付きノードとして出す(子ブロックに落到ると parse 失敗)。
            match = _: { props.app-id = "dev.noctalia.Noctalia"; };
            open-floating = true;
            default-column-width = {
              fixed = 1080;
            };
            default-window-height = {
              fixed = 920;
            };
          }
        ];

        layer-rules = [
          {
            match = _: {
              props.namespace = "^noctalia-(bar-[^\"]+|notification|dock|panel|attached-panel|osd)$";
            };
            background-effect = {
              xray = false;
            };
          }

          # overview の backdrop を Noctalia の backdrop layer に読ませる。
          {
            match = _: { props.namespace = "^noctalia-backdrop"; };
            place-within-backdrop = true;
          }
        ];

        # Noctalia からの通知アクションと window 起動を許可する。
        debug = {
          honor-xdg-activation-with-invalid-serial = _: { };
        };

        binds = {
          "Mod+Return".spawn = lib.getExe' terminal "terminal";
          "Mod+Q".close-window = _: { };
          "Mod+S".spawn-sh = "${lib.getExe pkgs.noctalia} msg panel-toggle launcher";

          "Mod+Shift+Slash".show-hotkey-overlay = _: { };
          "Mod+Shift+E".quit = _: { };
          "Mod+Escape" = _: {
            props.allow-inhibiting = false;
            content.toggle-keyboard-shortcuts-inhibit = _: { };
          };

          "Mod+H".focus-column-left = _: { };
          "Mod+L".focus-column-right = _: { };
          "Mod+J".focus-window-down = _: { };
          "Mod+K".focus-window-up = _: { };
          "Mod+U".focus-workspace-down = _: { };
          "Mod+I".focus-workspace-up = _: { };
          "Mod+Home".focus-column-first = _: { };
          "Mod+End".focus-column-last = _: { };

          "Mod+Ctrl+H".move-column-left = _: { };
          "Mod+Ctrl+L".move-column-right = _: { };
          "Mod+Ctrl+J".move-window-down = _: { };
          "Mod+Ctrl+K".move-window-up = _: { };
          "Mod+Ctrl+U".move-column-to-workspace-down = _: { };
          "Mod+Ctrl+I".move-column-to-workspace-up = _: { };
          "Mod+Ctrl+Home".move-column-to-first = _: { };
          "Mod+Ctrl+End".move-column-to-last = _: { };

          "Mod+Shift+H".focus-monitor-left = _: { };
          "Mod+Shift+L".focus-monitor-right = _: { };
          "Mod+Shift+J".focus-monitor-down = _: { };
          "Mod+Shift+K".focus-monitor-up = _: { };
          "Mod+Shift+U".move-workspace-down = _: { };
          "Mod+Shift+I".move-workspace-up = _: { };

          "Mod+Shift+Ctrl+H".move-column-to-monitor-left = _: { };
          "Mod+Shift+Ctrl+L".move-column-to-monitor-right = _: { };
          "Mod+Shift+Ctrl+J".move-column-to-monitor-down = _: { };
          "Mod+Shift+Ctrl+K".move-column-to-monitor-up = _: { };

          "Mod+1".focus-workspace = 1;
          "Mod+2".focus-workspace = 2;
          "Mod+3".focus-workspace = 3;
          "Mod+4".focus-workspace = 4;
          "Mod+5".focus-workspace = 5;
          "Mod+6".focus-workspace = 6;
          "Mod+7".focus-workspace = 7;
          "Mod+8".focus-workspace = 8;
          "Mod+9".focus-workspace = 9;
          "Mod+Ctrl+1".move-column-to-workspace = 1;
          "Mod+Ctrl+2".move-column-to-workspace = 2;
          "Mod+Ctrl+3".move-column-to-workspace = 3;
          "Mod+Ctrl+4".move-column-to-workspace = 4;
          "Mod+Ctrl+5".move-column-to-workspace = 5;
          "Mod+Ctrl+6".move-column-to-workspace = 6;
          "Mod+Ctrl+7".move-column-to-workspace = 7;
          "Mod+Ctrl+8".move-column-to-workspace = 8;
          "Mod+Ctrl+9".move-column-to-workspace = 9;

          "Mod+BracketLeft".consume-or-expel-window-left = _: { };
          "Mod+BracketRight".consume-or-expel-window-right = _: { };
          "Mod+Comma".consume-window-into-column = _: { };
          "Mod+Period".expel-window-from-column = _: { };

          "Mod+R".switch-preset-column-width = _: { };
          "Mod+Shift+R".switch-preset-column-width-back = _: { };
          "Mod+Minus".set-column-width = "-10%";
          "Mod+Equal".set-column-width = "+10%";
          "Mod+Shift+Minus".set-window-height = "-10%";
          "Mod+Shift+Equal".set-window-height = "+10%";
          "Mod+Ctrl+R".reset-window-height = _: { };
          "Mod+F".maximize-column = _: { };
          "Mod+Shift+F".fullscreen-window = _: { };
          "Mod+M".maximize-window-to-edges = _: { };
          "Mod+C".center-column = _: { };
          "Mod+V".toggle-window-floating = _: { };
          "Mod+W".toggle-column-tabbed-display = _: { };

          "Mod+O".toggle-overview = _: { };
          "Print".screenshot = _: { };
          "Ctrl+Print".screenshot-screen = _: { };
          "Alt+Print".screenshot-window = _: { };
        };
      };
    };

  flake.nixosModules.niri =
    { pkgs, lib, ... }:
    {
      programs.niri = {
        enable = true;
        package = self.packages.${pkgs.system}.desktop;
      };

      services.displayManager.defaultSession = lib.mkForce "niri";
    };
}
