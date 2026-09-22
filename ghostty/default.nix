{ self, ... }:
{
  flake.wrappers.terminal =
    { wlib, pkgs, ... }:
    let
      ghosttyCursorTrails = pkgs.fetchFromGitHub {
        owner = "hced";
        repo = "ghostty-cursor-trails";
        rev = "78f597cf66427bc382077e5e33f26981a86bb207";
        hash = "sha256-NHeCd/avyJ8SaYW8pYWcetwVroFQNokN7saiWCMu3TM=";
      };

      # 横移動時のカーソル残像が過度に長く見える問題の修正(縦方向の移動を無視)。
      patchedBooCursor = pkgs.runCommand "boo-cursor-patched" { } ''
        cp ${ghosttyCursorTrails}/boo-cursor.glsl $out
        substituteInPlace $out \
          --replace-fail 'float minDist = currentCursor.w * THRESHOLD_MIN_DISTANCE;' \
                         'vec2 _mv = centerCC - centerCP; float minDist = mix(currentCursor.w * 2.0, 1e10, step(abs(_mv.y), abs(_mv.x)));'
      '';

      # HOME や XDG を汚さずフォントを注入するための fontconfig 設定。
      # システム設定 (/etc/fonts/fonts.conf) を include した上で repo のフォントを追加走査する。
      fontconfigConf = pkgs.writeText "terminal-fontconfig.conf" ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
        <fontconfig>
          <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
          <dir>${terminalFonts}/share/fonts</dir>
        </fontconfig>
      '';

      terminalFonts = pkgs.symlinkJoin {
        name = "terminal-fonts";
        paths = with pkgs; [
          hackgen-nf-font
          noto-fonts-cjk-sans
          noto-fonts-color-emoji
        ];
      };
    in
    {
      imports = [ wlib.wrapperModules.ghostty ];

      aliases = [ "terminal" ];

      addFlag = [ "--gtk-single-instance=false" ];

      # 設定込みのツール一式を wrapper の実行時 PATH に注入し、
      # nix run github:<repo>#terminal だけで完結させる。
      runtimePkgs = [
        self.packages.${pkgs.system}.bash
        self.packages.${pkgs.system}.nvim
        self.packages.${pkgs.system}.opencode
        self.packages.${pkgs.system}.zellij
      ];

      env = {
        # zellij のペインシェルは $SHELL 参照なので repo bash にピン留めする。
        SHELL = "${self.packages.${pkgs.system}.bash}/bin/bash";
        FONTCONFIG_FILE = "${fontconfigConf}";
      };

      settings = {
        font-family = "HackGen Console NF";
        font-size = 18;
        window-padding-x = 14;
        window-padding-y = 14;
        window-decoration = "none";
        background-opacity = 0.6;
        background-blur = 20;
        command = "zellij";
        term = "xterm-256color";
        background = "#16181a";
        foreground = "#ffffff";
        palette = [
          "0=#16181a"
          "1=#ff6e5e"
          "2=#5eff6c"
          "3=#f1ff5e"
          "4=#5ea1ff"
          "5=#bd5eff"
          "6=#5ef1ff"
          "7=#ffffff"
          "8=#3c4048"
          "9=#ff6e5e"
          "10=#5eff6c"
          "11=#f1ff5e"
          "12=#5ea1ff"
          "13=#bd5eff"
          "14=#5ef1ff"
          "15=#ffffff"
        ];
        selection-background = "#3c4048";
        selection-foreground = "#ffffff";
        window-show-tab-bar = "never";
        mouse-hide-while-typing = true;
        cursor-style-blink = false;
        copy-on-select = "clipboard";
        confirm-close-surface = false;
        custom-shader = "${patchedBooCursor}";
        custom-shader-animation = "always";
        keybind = [
          "clear"
          "ctrl+shift+c=copy_to_clipboard"
          "ctrl+shift+v=paste_from_clipboard"
        ];
      };
    };

  flake.homeModules.ghostty =
    { pkgs, ... }:
    {
      home.packages = [ self.packages.${pkgs.system}.terminal ];
    };
}
