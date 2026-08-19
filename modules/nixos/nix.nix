{
  config,
  lib,
  username,
  ...
}:

with lib;

let
  cfg = config.domains.nix;
in
{
  options.domains.nix = {
    maxJobs = mkOption {
      type = types.nullOr types.int;
      default = null;
    };
    sandbox = mkOption {
      type = types.bool;
      default = true;
    };
  };

  config = mkMerge [
    {
      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        trusted-users = [ username ];
        sandbox = cfg.sandbox;
      };
      nixpkgs.config.allowUnfree = true;
      system.stateVersion = "26.11";
    }
    (mkIf (cfg.maxJobs != null) {
      nix.settings."max-jobs" = cfg.maxJobs;
    })
  ];
}
