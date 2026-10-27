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
              nix run .#dsh-skills-update
              nix run .#qwencloud-update
              nix run .#kimaki-update
            '';
          };
        in
        {
          type = "app";
          program = "${updateScript}/bin/dotfiles-update";
        };
    };
}
