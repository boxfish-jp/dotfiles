{ self, ... }:
{
  flake.nixosModules.keyboard =
    { config, lib, ... }:

    {
      services.xserver.xkb = {
        layout = "jp";
        variant = "";
      };
    }

  ;
}
