{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.domains.fonts;
in
{
  options.domains.fonts = {
    defaultFonts = mkEnableOption "fontconfig 既定フォント設定 (デスクトップ向け)";
  };

  config = mkMerge [
    {
      fonts = {
        packages = with pkgs; [
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-color-emoji
          hackgen-nf-font
        ];
        fontDir.enable = true;
      };
    }
    (mkIf cfg.defaultFonts {
      fonts.fontconfig = {
        defaultFonts = {
          serif = [
            "Noto Serif CJK JP"
            "Noto Color Emoji"
          ];
          sansSerif = [
            "Noto Sans CJK JP"
            "Noto Clor Emoji"
          ];
          emoji = [ "Noto Color Emoji" ];
        };
      };
    })
  ];
}
