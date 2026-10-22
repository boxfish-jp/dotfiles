{ self, ... }:
{
  flake.nixosModules.bubblewrap =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.bubblewrap ];
    };
}
