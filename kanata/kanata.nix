{
  config,
  pkgs,
  lib,
  ...
}:
let
  kanata-with-cmd = pkgs.kanata.override { withCmd = true; };
in
{
  home.packages = [
    kanata-with-cmd
  ];

  systemd.user.services = {
    kanata = {
      Unit = {
        Description = "Kanata keyboard remapper (with cmd)";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${kanata-with-cmd}/bin/kanata --cfg %h/.config/kanata/kanata.kbd";
        Restart = "on-failure";
        RestartSec = "2s";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };

  xdg.configFile."kanata".source = ./.;
}
