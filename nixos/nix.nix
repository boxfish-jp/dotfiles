{ self, ... }:
{
  flake.nixosModules.nix =
    {
      config,
      lib,
      users,
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
        atticEndpoint = mkOption {
          type = types.nullOr types.str;
          default = "http://monitor-server.taildb6ca.ts.net:8080/shared";
          example = "http://monitor-server.taildb6ca.ts.net:8080/shared";
          description = "自前 attic キャッシュの substituter URL。null のときは使わない。";
        };
        atticPublicKey = mkOption {
          type = types.nullOr types.str;
          default = "shared:sm7OWaMrlVQqfEGCymYziZ8TzBl0ft0LBTRI2boAJPE=";
          example = "shared:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=";
          description = "自前 attic キャッシュの公開鍵 (`attic cache info` で取得)。null のときは使わない。";
        };
      };

      config = mkMerge [
        {
          nix.settings = {
            experimental-features = [
              "nix-command"
              "flakes"
            ];
            trusted-users = users;
            sandbox = cfg.sandbox;
          };
          nixpkgs.config.allowUnfree = true;
          system.stateVersion = "26.11";
        }
        (mkIf (cfg.maxJobs != null) {
          nix.settings."max-jobs" = cfg.maxJobs;
        })
        (mkIf (cfg.atticEndpoint != null && cfg.atticPublicKey != null) {
          nix.settings.extra-substituters = [ cfg.atticEndpoint ];
          nix.settings.extra-trusted-public-keys = [ cfg.atticPublicKey ];
        })
      ];
    }

  ;
}
