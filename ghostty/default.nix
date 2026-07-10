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
in {
  home.packages = [
    pkgs.ghostty
  ];

  xdg.configFile = {
    # config ファイルだけ個別にシンボリックリンク（リポジトリ内で直接編集可能）
    "ghostty/config".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/ghostty/config";

    # カーソルトレイルシェーダー
    "ghostty/shaders/ghostty-cursor-trails/boo-cursor.glsl".source =
      "${ghosttyCursorTrails}/boo-cursor.glsl";
    "ghostty/shaders/ghostty-cursor-trails/tinkle-cursor.glsl".source =
      "${ghosttyCursorTrails}/tinkle-cursor.glsl";
    "ghostty/shaders/ghostty-cursor-trails/wisp-cursor.glsl".source =
      "${ghosttyCursorTrails}/wisp-cursor.glsl";
  };
}
