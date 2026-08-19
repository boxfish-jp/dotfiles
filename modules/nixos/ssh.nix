{ config, lib, ... }:

with lib;

let
  cfg = config.domains.ssh;
in
{
  options.domains.ssh = {
    rootLogin = mkEnableOption "ルートログイン許可 (LXCコンテナ向け)";
  };

  config.services.openssh = {
    enable = true;
    openFirewall = true;
    settings =
      if cfg.rootLogin then
        {
          PermitRootLogin = "yes";
          PasswordAuthentication = true;
          PermitEmptyPasswords = "yes";
        }
      else
        {
          PermitRootLogin = "no";
          PasswordAuthentication = true;
          KbdInteractiveAuthentication = false;
          MaxAuthTries = 3;
          PerSourcePenalties = "crash:3600s authfail:3600s max:86400s";
        };
  };
}
