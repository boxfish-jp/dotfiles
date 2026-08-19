{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.domains.locale;
in
{
  options.domains.locale = {
    japanese = mkEnableOption "日本語環境 (ja_JP ロケール + fcitx5/mozc 入力)";
  };

  config = {
    time.timeZone = "Asia/Tokyo";

    i18n = mkIf cfg.japanese {
      defaultLocale = "ja_JP.UTF-8";

      inputMethod = {
        enable = true;
        type = "fcitx5";
        fcitx5.addons = with pkgs; [
          fcitx5-mozc-ut
        ];
        fcitx5.waylandFrontend = true;
      };

      extraLocaleSettings = {
        LC_ADDRESS = "ja_JP.UTF-8";
        LC_IDENTIFICATION = "ja_JP.UTF-8";
        LC_MEASUREMENT = "ja_JP.UTF-8";
        LC_MONETARY = "ja_JP.UTF-8";
        LC_NAME = "ja_JP.UTF-8";
        LC_NUMERIC = "ja_JP.UTF-8";
        LC_PAPER = "ja_JP.UTF-8";
        LC_TELEPHONE = "ja_JP.UTF-8";
        LC_TIME = "ja_JP.UTF-8";
      };
    };
  };
}
