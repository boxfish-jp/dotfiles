{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      ghosttyCursorTrails = pkgs.fetchFromGitHub {
        owner = "hced";
        repo = "ghostty-cursor-trails";
        rev = "78f597cf66427bc382077e5e33f26981a86bb207";
        hash = "sha256-NHeCd/avyJ8SaYW8pYWcetwVroFQNokN7saiWCMu3TM=";
      };

      patchedBooCursor = pkgs.runCommand "boo-cursor-patched" { } ''
        cp ${ghosttyCursorTrails}/boo-cursor.glsl $out
        substituteInPlace $out \
          --replace-fail 'float minDist = currentCursor.w * THRESHOLD_MIN_DISTANCE;' \
                         'vec2 _mv = centerCC - centerCP; float minDist = mix(currentCursor.w * 2.0, 1e10, step(abs(_mv.y), abs(_mv.x)));'
      '';

      # 設定ツリー（config と shaders/ を同梱）。
      # config 内の custom-shader 相対パスはファイル所在ディレクトリ基準で解決される。
      # 先頭に空値の custom-shader を挿入し、XDG 側に設定が残っていても
      # シェーダーが二重適用されないようにする。
      ghosttyConfigTree = pkgs.runCommand "ghostty-config" { } ''
        mkdir -p $out/shaders/ghostty-cursor-trails
        cp ${ghosttyCursorTrails}/tinkle-cursor.glsl $out/shaders/ghostty-cursor-trails/
        cp ${ghosttyCursorTrails}/wisp-cursor.glsl $out/shaders/ghostty-cursor-trails/
        cp ${patchedBooCursor} $out/shaders/ghostty-cursor-trails/boo-cursor.glsl
        cp ${./config} $out/config
        chmod u+w $out/config
        sed -i '0,/^custom-shader =/s//custom-shader =\n&/' $out/config
      '';

      # --config-file は XDG 既定設定の後に読まれ後勝ち。
      # --gtk-single-instance=false は既存インスタンスへのフォワード（設定無視で開く）を防ぐため。
      ghostty = pkgs.writeShellScriptBin "ghostty" ''
        exec ${pkgs.lib.getExe pkgs.ghostty} \
          --gtk-single-instance=false \
          --config-file=${ghosttyConfigTree}/config \
          "$@"
      '';
    in
    {
      packages.ghostty = ghostty;
    };

  flake.homeModules.ghostty =
    { pkgs, ... }:
    {
      home.packages = [ self.packages.${pkgs.system}.ghostty ];
    };
}
