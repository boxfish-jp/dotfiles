{ lib, ... }:
let
  mkBash =
    { pkgs }:
    let
      rcFile = pkgs.writeText "bashrc" (builtins.readFile ./bashrc);
    in
    pkgs.runCommand "bash"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        meta.mainProgram = "bash";
      }
      ''
        mkdir -p $out/bin
        makeWrapper ${lib.getExe pkgs.bashInteractive} $out/bin/bash \
          --argv0 bash \
          --prefix PATH : "${lib.makeBinPath [ pkgs.starship ]}" \
          --add-flags "--rcfile ${rcFile}"
      '';
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages.bash = mkBash { inherit pkgs; };
    };

  flake.homeModules.bash =
    {
      config,
      pkgs,
      lib,
      hostname,
      ...
    }:
    {
      home.file.".mybashrc".source = ./bashrc;

      home.packages = with pkgs; [
        starship
      ];

      programs.bash = {
        enable = true;
        initExtra = ''
          source ~/.profile
          source ~/.mybashrc
        '';
      };
    };
}
