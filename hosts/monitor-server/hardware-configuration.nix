# 要置換スタブ: 実機で nixos-generate-config を実行し、その出力でこのファイルを
# 置き換えること(laptop の hosts/laptop/hardware-configuration.nix と同型)。
# このままデプロイすると起動しない。
{
  flake.nixosModules."host-monitor-server" =
    { modulesPath, ... }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-label/boot";
        fsType = "vfat";
      };
    };
}
