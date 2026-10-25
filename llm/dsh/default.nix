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
      dsh = inputs.dsh-profile-nix.lib.mkDsh {
        inherit pkgs;
        dsh = inputs.llm-agents.packages.${pkgs.system}.dsh;
        # mkDsh の既定は 8080 だが、dsh の web 既定は 3080 なので合わせる。
        webPort = 3080;
        skills = [ ../skills ];
        plugins = plugins.listFor pkgs;
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
    };
}
