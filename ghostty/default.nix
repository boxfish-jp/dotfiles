{
  config,
  pkgs,
  lib,
  ...
}:

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
in {
  home.packages = [
    pkgs.ghostty
  ];

  xdg.configFile = {
    "ghostty/config".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/ghostty/config";

    "ghostty/shaders/ghostty-cursor-trails/boo-cursor.glsl".source =
      "${patchedBooCursor}";
    "ghostty/shaders/ghostty-cursor-trails/tinkle-cursor.glsl".source =
      "${ghosttyCursorTrails}/tinkle-cursor.glsl";
    "ghostty/shaders/ghostty-cursor-trails/wisp-cursor.glsl".source =
      "${ghosttyCursorTrails}/wisp-cursor.glsl";
  };
}
