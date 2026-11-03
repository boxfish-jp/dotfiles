{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      apps.update =
        let
          updateScript = pkgs.writeShellApplication {
            name = "dotfiles-update";
            runtimeInputs = [ pkgs.nix ];
            text = ''
              nix flake update
              nix run .#dsh-plugins-update
              nix run .#dsh-skills-update
            '';
          };
        in
        {
          type = "app";
          program = "${updateScript}/bin/dotfiles-update";
        };
    };
}
