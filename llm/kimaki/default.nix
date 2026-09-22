{ self, ... }:
{
  flake.homeModules.kimaki =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.llm.kimaki;
      kimakiPkg = pkgs.callPackage ./_package.nix { };
    in
    {
      options.llm.kimaki.enable = lib.mkEnableOption "kimaki";

      config = lib.mkIf cfg.enable {
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
      };
    }

  ;
}
