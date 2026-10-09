{ self, ... }:
{
  flake.nixosModules.desktop = { config, lib, ... }: {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    services.xserver.enable = true;

    # sddm の代わりに Noctalia 製ログイン画面(greetd ベース)を使う。
    # noctalia-greeter 側で greetd が有効化され、セッション選択は
    # services.displayManager の sessionPackages(defaultSession)に従う。
    services.displayManager.noctalia-greeter = {
      enable = true;
      settings.keyboard.layout = "jp";
    };
  };

  flake.vmTests.desktop.modules = [ self.nixosModules.desktop ];
}
