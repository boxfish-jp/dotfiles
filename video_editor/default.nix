{ inputs, ... }:
{
  perSystem =
    { system, lib, ... }:
    let
      unfreePkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      packages = {
        davinci-resolve = unfreePkgs.davinci-resolve;
        voicevox = unfreePkgs.voicevox;
      };

      apps = {
        davinci-resolve = {
          type = "app";
          program = lib.getExe unfreePkgs.davinci-resolve;
        };
        voicevox = {
          type = "app";
          program = lib.getExe unfreePkgs.voicevox;
        };
      };
    };
}
