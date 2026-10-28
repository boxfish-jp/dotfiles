# Agents Anywhere のセルフホスト Server を podman コンテナで動かす。
#
# 上流の docker/docker-compose.postgres.yml と同じ構成
# (PostgreSQL → Redis → 一回限りの migration → Server) を NixOS の
# virtualisation.oci-containers で宣言する。イメージは上流 Dockerfile から
# 初回起動時に podman build する (上流はコンテナイメージを公開していない)。
{
  self,
  ...
}:
{
  flake.nixosModules.agents_anywhere =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.agents_anywhere;
      inherit (lib)
        mkEnableOption
        mkIf
        mkOption
        types
        ;

      version = "2.1.0";

      # llm/dsh/_agents-anywhere.nix と同じリビジョンに固定する。
      # 上流は server/uv.lock と web-next/yarn.lock をコミットしていないため、
      # イメージ内の依存はビルド時点の最新になる。更新は version/rev を上げて
      # agents-anywhere-image を再ビルドする。
      source = pkgs.fetchgit {
        url = "https://github.com/anywhere-labs/Agents-Anywhere";
        rev = "4ccfe15e3358b657b6b958e49367c8541f9a3d43";
        hash = "sha256-PC+ATxFXt+hLNzpIvTASC9hObq2VFJbs5/EPb/McmkA=";
      };

      image = "agents-anywhere-server:${version}";
      envFile = "${cfg.dataDir}/server.env";

      dbName = "agents_anywhere";
      dbUser = "agents_anywhere";

      # podman のコンテナ DNS (aardvark-dns) は getaddrinfo で不安定だったため、
      # 3 コンテナとも host network で動かし 127.0.0.1 だけを listen させる。
      dbHost = "127.0.0.1";
      redisHost = "127.0.0.1";

      serverEnv = {
        AGENT_SERVER_HOST = "127.0.0.1";
        AGENT_SERVER_PORT = toString cfg.port;
        AGENT_SERVER_REDIS_URL = "redis://${redisHost}:6379/0";
        AGENT_SERVER_FILES_BACKEND = "local";
        AGENT_SERVER_FILES_LOCAL_ROOT = "/data/agent-server.files";
        AGENT_SERVER_PUBLIC_ORIGIN = cfg.publicOrigin;
        AGENT_SERVER_CORS_ORIGINS = lib.concatStringsSep "," (
          [ "http://127.0.0.1:${toString cfg.port}" ]
          ++ lib.optional (cfg.publicOrigin != "") cfg.publicOrigin
        );
      };
    in
    {
      options.services.agents_anywhere = {
        enable = mkEnableOption "Agents Anywhere のセルフホスト Server";

        port = mkOption {
          type = types.port;
          default = 5174;
          description = "ホストの 127.0.0.1 に公開するポート。外部公開は tailscale serve かリバースプロキシで行う。";
        };

        dataDir = mkOption {
          type = types.str;
          default = "/var/lib/agents-anywhere";
          description = "生成した secret と env ファイルを置くディレクトリ。";
        };

        publicOrigin = mkOption {
          type = types.str;
          default = "";
          example = "https://nixos-ct.taildb6ca.ts.net";
          description = ''
            クライアントがアクセスする URL。CORS と AGENT_SERVER_PUBLIC_ORIGIN に使う。
            空の場合は 127.0.0.1 のオリジンだけを許可する。
          '';
        };

        tailscaleServe = mkOption {
          type = types.bool;
          default = false;
          description = "tailscale serve で https://<host>.<tailnet>.ts.net に公開する。";
        };
      };

      config = mkIf cfg.enable {
        # 上流 Dockerfile は `FROM node:22-bookworm-slim` のような未修飾名を使う。
        # NixOS の既定では検索先が空で podman build が失敗するため docker.io を補う。
        virtualisation.containers.registries.settings = {
          unqualified-search-registries = [ "docker.io" ];
        };

        virtualisation.oci-containers = {
          backend = "podman";

          containers = {
            agents-anywhere-postgres = {
              image = "docker.io/library/postgres:17-alpine";
              networks = [ "host" ];
              cmd = [
                "-c"
                "listen_addresses=127.0.0.1"
              ];
              environment = {
                POSTGRES_DB = dbName;
                POSTGRES_USER = dbUser;
              };
              environmentFiles = [ envFile ];
              volumes = [ "agents-anywhere-pg:/var/lib/postgresql/data" ];
              extraOptions = [
                "--health-cmd=pg_isready -U ${dbUser} -d ${dbName}"
                "--health-interval=5s"
                "--health-timeout=3s"
                "--health-retries=12"
              ];
            };

            agents-anywhere-redis = {
              image = "docker.io/library/redis:8-alpine";
              networks = [ "host" ];
              cmd = [
                "redis-server"
                "--bind"
                "127.0.0.1"
                "--save"
                ""
                "--appendonly"
                "yes"
                "--appendfsync"
                "everysec"
                "--maxmemory"
                "256mb"
                "--maxmemory-policy"
                "noeviction"
              ];
              volumes = [ "agents-anywhere-redis:/data" ];
            };

            agents-anywhere-server = {
              image = image;
              pull = "never";
              networks = [ "host" ];
              dependsOn = [
                "agents-anywhere-postgres"
                "agents-anywhere-redis"
              ];
              environmentFiles = [ envFile ];
              environment = serverEnv;
              volumes = [ "agents-anywhere-files:/data" ];
            };
          };
        };

        systemd.services = {
          # DB パスワードと Server secret は初回だけ生成する。
          # 再生成するとセッションとログインが壊れるので、ファイルがあれば触らない。
          agents-anywhere-secrets = {
            wantedBy = [ "multi-user.target" ];
            before = [ "agents-anywhere-image.service" ];
            path = [
              pkgs.coreutils
              pkgs.openssl
            ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              UMask = "0077";
            };
            script = ''
              install -d -m 0700 ${cfg.dataDir}
              if [ ! -s ${envFile} ]; then
                password=$(openssl rand -hex 24)
                secret=$(openssl rand -hex 32)
                printf '%s\n' \
                  "POSTGRES_PASSWORD=$password" \
                  "AGENT_SERVER_SECRET=$secret" \
                  "AGENT_SERVER_DB_URL=postgresql+asyncpg://${dbUser}:$password@${dbHost}:5432/${dbName}" \
                  > ${envFile}
              fi
            '';
          };

          agents-anywhere-image = {
            wantedBy = [ "multi-user.target" ];
            after = [
              "network-online.target"
              "agents-anywhere-secrets.service"
            ];
            wants = [ "network-online.target" ];
            requires = [ "agents-anywhere-secrets.service" ];
            path = [
              pkgs.buildah
              pkgs.podman
            ];
            environment.HOME = "/root";
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              TimeoutStartSec = 3600;
            };
            script = ''
              if ! podman image exists ${image}; then
                podman build \
                  --target server \
                  --tag ${image} \
                  --file ${source}/docker/Dockerfile \
                  ${source}
              fi
            '';
          };

          # Alembic は DB が接続を受け付けるまで失敗するので、起動順の保証だけでは
          # 足りない。migrator 側でリトライする。
          agents-anywhere-migrate = {
            wantedBy = [ "multi-user.target" ];
            after = [
              "agents-anywhere-image.service"
              "podman-agents-anywhere-postgres.service"
              "podman-agents-anywhere-redis.service"
            ];
            requires = [
              "agents-anywhere-image.service"
              "podman-agents-anywhere-postgres.service"
              "podman-agents-anywhere-redis.service"
            ];
            path = [ pkgs.podman ];
            environment.HOME = "/root";
            restartTriggers = [ image ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              TimeoutStartSec = 600;
            };
            script = ''
              for _ in $(seq 1 60); do
                if podman run --rm \
                  --pull=never \
                  --name agents-anywhere-migrate \
                  --network host \
                  --env-file ${envFile} \
                  ${image} \
                  sh -c 'cd /app/server && uv run --no-sync python -m agent_server.infra.db.migrations upgrade'; then
                  exit 0
                fi
                sleep 2
              done
              exit 1
            '';
          };

          "podman-agents-anywhere-postgres" = {
            requires = [ "agents-anywhere-secrets.service" ];
            after = [ "agents-anywhere-secrets.service" ];
          };

          "podman-agents-anywhere-server" = {
            requires = [
              "agents-anywhere-migrate.service"
              "agents-anywhere-secrets.service"
            ];
            after = [
              "agents-anywhere-migrate.service"
              "agents-anywhere-secrets.service"
            ];
          };
        };

        systemd.services.agents-anywhere-tailscale-serve = mkIf cfg.tailscaleServe {
          wantedBy = [ "multi-user.target" ];
          after = [
            "podman-agents-anywhere-server.service"
            "tailscaled.service"
          ];
          requires = [
            "podman-agents-anywhere-server.service"
            "tailscaled.service"
          ];
          path = [ pkgs.tailscale ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --https=443 http://127.0.0.1:${toString cfg.port}";
            ExecStop = "-${pkgs.tailscale}/bin/tailscale serve --https=443 off";
          };
        };
      };
    };
}
