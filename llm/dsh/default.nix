{
  inputs,
  lib,
  ...
}:
let
  plugins = import ./_plugins.nix { inherit inputs lib; };
in
{
  perSystem =
    { pkgs, ... }:
    let
      mcpBundle = pkgs.runCommand "dsh-config-mcp" { } ''
        mkdir -p "$out"
        cp ${./config/mcp/package.json} "$out/package.json"
        cp ${./config/mcp/cordis.patch.yml} "$out/cordis.patch.yml"
      '';

      dsh = inputs.dsh-profile-nix.lib.mkDsh {
        inherit pkgs;
        dsh = inputs.llm-agents.packages.${pkgs.system}.dsh;
        # mkDsh の既定は 8080 だが、dsh の web 既定は 3080 なので合わせる。
        webPort = 3080;
        skills = [ ../skills ];
        plugins = plugins.listFor pkgs ++ [ mcpBundle ];
        profiles = {
          web = { };
        };
      };
    in
    {
      packages = plugins.packagesFor pkgs // {
        inherit dsh;
      };

      apps.dsh-plugins-update = {
        type = "app";
        program = lib.getExe (plugins.updateScript pkgs);
      };
    };

  flake.homeModules.dsh =
    { pkgs, self, ... }:
    {
      home.packages = [ self.packages.${pkgs.system}.dsh ];

      # dsh は $DSH_HOME/AGENTS.md を全セッション共通の指示として読む。
      home.file.".dsh/AGENTS.md".source = ./AGENTS.md;
    };
}
