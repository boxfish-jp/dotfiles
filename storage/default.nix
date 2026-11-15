{ self, ... }:
{
  flake.nixosModules.storage =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      cfg = config.domains.storage;
      stateDir = "versitygw";
    in
    {
      options.domains.storage = {
        versitygw = {
          enable = lib.mkEnableOption "versitygw S3 ゲートウェイ (posix バックエンド)";

          port = lib.mkOption {
            type = lib.types.port;
            default = 7070;
            description = "S3 API の待ち受けポート。";
          };

          envFile = lib.mkOption {
            type = lib.types.str;
            default = "/etc/versitygw.env";
            description = "ROOT_ACCESS_KEY と ROOT_SECRET_KEY を定義する EnvironmentFile (0600 root)。";
          };

          buckets = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "media"
              "restic"
            ];
            description = "起動時に冪等に作成するバケット。";
          };
        };

        immichBackup = {
          enable = lib.mkEnableOption "immich メディアの S3 への日次 rclone sync";

          source = lib.mkOption {
            type = lib.types.str;
            default = toString config.services.immich.mediaLocation;
            description = "同期元の immich メディアディレクトリ。";
          };

          envFile = lib.mkOption {
            type = lib.types.str;
            default = "/etc/rclone-s3.env";
            description = "RCLONE_CONFIG_S3_* を定義する EnvironmentFile (0600 root)。";
          };

          bucket = lib.mkOption {
            type = lib.types.str;
            default = "media";
            description = "同期先バケット。";
          };

          prefix = lib.mkOption {
            type = lib.types.str;
            default = "immich";
            description = "同期先バケット内の prefix。";
          };

          onCalendar = lib.mkOption {
            type = lib.types.str;
            default = "*-*-* 03:00:00";
            description = "systemd timer の OnCalendar 式。";
          };
        };
      };

      config = lib.mkMerge [
        (lib.mkIf cfg.versitygw.enable {
          users.groups.versitygw = { };
          users.users.versitygw = {
            isSystemUser = true;
            group = "versitygw";
          };

          systemd.services.versitygw = {
            description = "versitygw S3 gateway";
            wantedBy = [ "multi-user.target" ];
            after = [ "network.target" ];
            serviceConfig = {
              User = "versitygw";
              Group = "versitygw";
              ExecStart = "${pkgs.versitygw}/bin/versitygw --port 0.0.0.0:${toString cfg.versitygw.port} posix --fsync /var/lib/${stateDir}";
              EnvironmentFile = cfg.versitygw.envFile;
              StateDirectory = stateDir;
              StateDirectoryMode = "0700";
              Restart = "on-failure";
              RestartSec = "5s";
              NoNewPrivileges = true;
              PrivateTmp = true;
              PrivateDevices = true;
              ProtectSystem = "strict";
              ProtectHome = true;
              ProtectKernelTunables = true;
              ProtectKernelModules = true;
              ProtectControlGroups = true;
              RestrictAddressFamilies = [
                "AF_UNIX"
                "AF_INET"
                "AF_INET6"
                "AF_NETLINK"
              ];
              RestrictNamespaces = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              LockPersonality = true;
            };
          };

          systemd.services.versitygw-buckets = {
            description = "Create versitygw buckets";
            wantedBy = [ "multi-user.target" ];
            after = [ "versitygw.service" ];
            requires = [ "versitygw.service" ];
            path = [
              pkgs.awscli2
              pkgs.coreutils
            ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              EnvironmentFile = cfg.versitygw.envFile;
              NoNewPrivileges = true;
              PrivateTmp = true;
              ProtectHome = true;
              ProtectSystem = "strict";
              RestrictAddressFamilies = [
                "AF_INET"
                "AF_INET6"
                "AF_UNIX"
              ];
            };
            script = ''
              export AWS_ACCESS_KEY_ID="$ROOT_ACCESS_KEY"
              export AWS_SECRET_ACCESS_KEY="$ROOT_SECRET_KEY"
              export AWS_DEFAULT_REGION="us-east-1"
              export AWS_EC2_METADATA_DISABLED="true"

              endpoint="http://127.0.0.1:${toString cfg.versitygw.port}"
              attempt=0
              until aws --endpoint-url "$endpoint" s3api list-buckets >/dev/null 2>&1; do
                attempt=$((attempt + 1))
                if [ "$attempt" -ge 60 ]; then
                  echo "versitygw did not become ready on $endpoint" >&2
                  exit 1
                fi
                sleep 1
              done

              for bucket in ${lib.concatStringsSep " " (map lib.escapeShellArg cfg.versitygw.buckets)}; do
                if ! aws --endpoint-url "$endpoint" s3api head-bucket --bucket "$bucket" >/dev/null 2>&1; then
                  aws --endpoint-url "$endpoint" s3api create-bucket --bucket "$bucket"
                fi
              done
            '';
          };
        })

        (lib.mkIf cfg.immichBackup.enable {
          systemd.services.immich-s3-backup = {
            description = "Sync immich media to S3";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            unitConfig.RequiresMountsFor = cfg.immichBackup.source;
            preStart = ''
              media=${lib.escapeShellArg cfg.immichBackup.source}
              test -d "$media" && [ -n "$(ls -A "$media")" ] || {
                echo "immich media source is missing or empty: $media" >&2
                exit 1
              }
            '';
            serviceConfig = {
              Type = "oneshot";
              EnvironmentFile = cfg.immichBackup.envFile;
              ExecStart = "${pkgs.rclone}/bin/rclone sync ${cfg.immichBackup.source} s3:${cfg.immichBackup.bucket}/${cfg.immichBackup.prefix} --max-delete 1000 --cache-dir /var/cache/rclone --config /dev/null";
              CacheDirectory = "rclone";
              NoNewPrivileges = true;
              PrivateTmp = true;
              PrivateDevices = true;
              ProtectSystem = "strict";
              ProtectHome = true;
              RestrictAddressFamilies = [
                "AF_INET"
                "AF_INET6"
                "AF_UNIX"
              ];
              RestrictSUIDSGID = true;
              LockPersonality = true;
            };
          };

          systemd.timers.immich-s3-backup = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = cfg.immichBackup.onCalendar;
              Persistent = true;
            };
          };
        })
      ];
    };
}
