{ self, ... }:
{
  # 設定込みの noctalia-shell 。settings は upstream デフォルトのまま焼く。
  # 運用中に GUI で触ったら `dump-noctalia-shell`(ラッパー同梱)の出力をここで還流する。
  flake.wrappers.noctalia =
    { wlib, ... }:
    {
      imports = [ wlib.wrapperModules.noctalia-shell ];

      settings = { };
    };
}
