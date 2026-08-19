{
  config,
  lib,
  username,
  ...
}:

with lib;

let
  cfg = config.domains.users;
in
{
  options.domains.users = {
    extraGroups = mkOption {
      type = types.listOf types.str;
      default = [
        "networkmanager"
        "wheel"
        "podman"
      ];
    };
    linger = mkEnableOption "ユーザーの linger 有効化";
  };

  config.users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = cfg.extraGroups;
    linger = cfg.linger;
  };
}
