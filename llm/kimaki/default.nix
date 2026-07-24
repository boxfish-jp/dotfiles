{
  config,
  pkgs,
  lib,
  ...
}:
let
  kimakiPkg = pkgs.callPackage ./package.nix { };
in
{
  home.packages = [ kimakiPkg ];

  systemd.user.services.kimaki = {
    Unit = {
      Description = "Kimaki — collaborative agent orchestrator via Discord";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${kimakiPkg}/bin/kimaki --data-dir %h/.local/share/kimaki";
      EnvironmentFile = "%h/.config/kimaki/.env";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
