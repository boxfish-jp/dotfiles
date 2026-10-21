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
    {
      config,
      pkgs,
      ...
    }:
    let
      dshHome = "${config.home.homeDirectory}/${dshHomeRel}";
    in
    {
      home.packages = [ pkgs.llm-agents.dsh ];

      home.sessionVariables.DSH_HOME = dshHome;

      home.file."${dshHomeRel}/skills".source = ../skills;
    };
}
