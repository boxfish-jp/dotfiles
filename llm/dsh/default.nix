{
  inputs,
  lib,
  ...
}:
let
  dshHomeRel = ".config/dotfiles/llm/dsh";
in
{
  perSystem =
    { pkgs, system, ... }:
    {
      packages.dsh =
        let
          base = inputs.llm-agents.packages.${system}.dsh;
        in
        pkgs.writeShellScriptBin "dsh" ''
          export DSH_HOME="''${DSH_HOME:-$HOME/${dshHomeRel}}"
          if [ "$#" -eq 0 ]; then
            set -- web
          fi
          exec ${lib.getExe base} "$@"
        '';
    };

  flake.homeModules.dsh =
    { config, pkgs, ... }:
    {
      home.packages = [ pkgs.llm-agents.dsh ];

      # dsh のランタイムデータ（sessions / storages / profiles）を置く場所。
      # ワークツリー内なので .gitignore で追跡除外している。
      home.sessionVariables.DSH_HOME = "${config.home.homeDirectory}/${dshHomeRel}";
    };
}
