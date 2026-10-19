{ lib, ... }:
let
  # zellij 設定ツリー（config.kdl と themes/ のみ）
  zellijConfigTree = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./config.kdl
      ./themes
    ];
  };
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages.zellij = pkgs.writeShellApplication {
        name = "zellij";
        runtimeInputs = [ pkgs.zellij ];
        runtimeEnv.ZELLIJ_CONFIG_DIR = zellijConfigTree;
        text = ''zellij "$@"'';
      };
    };

  flake.homeModules.zellij =
    { config, pkgs, ... }:
    {
      home.packages = [ pkgs.zellij ];
      xdg.configFile."zellij".source = ./.;
    };
}
