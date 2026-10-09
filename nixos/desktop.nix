{ self, ... }:
{
  flake.nixosModules.desktop = { config, lib, ... }: {
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
  };

  flake.vmTests.desktop.modules = [ self.nixosModules.desktop ];
}
