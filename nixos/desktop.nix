{ self, ... }:
{
  flake.nixosModules.desktop = { ... }: {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    services.xserver.enable = true;

    # Noctalia 製ログイン画面(greetd ベース)を使う。
    services.displayManager.noctalia-greeter = {
      enable = true;
      settings.keyboard.layout = "jp";
    };

    # Noctalia のバッテリーウィジェット(UPower)と電源プロファイルのバックエンド。
    services.upower.enable = true;
    services.power-profiles-daemon.enable = true;

    # Solid/Dolphin がリムーバブルデバイス検出・マウント操作に依存する。
    services.udisks2.enable = true;

    # ddcutil 経由の DDC/CI 調光は /dev/i2c-* が必要。i2c-dev を読み、uaccess で seat ユーザに許可する。
    hardware.i2c.enable = true;
  };

  flake.vmTests.desktop.modules = [ self.nixosModules.desktop ];
}
