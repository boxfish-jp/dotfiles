{ self, ... }:
{
  flake.homeModules.dsh-web =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.llm.dsh.web;

      dsh =
        if config.llm.dsh.agentsAnywhere.enable then
          self.packages.${pkgs.system}.dsh-agents-anywhere
        else
          self.packages.${pkgs.system}.dsh;

      stateDir = "${config.home.homeDirectory}/.local/state/dsh";
      urlFile = "${stateDir}/web-url";

      extraTrustedHosts = lib.concatMapStringsSep "\n" (
        authority: "trusted+=(--trusted-host ${lib.escapeShellArg authority})"
      ) cfg.trustedHosts;

      resolveHost =
        if cfg.host == null then
          ''
            host=""
            for ((attempt = 0; attempt < 30; attempt++)); do
              host=$(tailscale ip -4 2>/dev/null | head -n 1 || true)
              if [ -n "$host" ]; then
                break
              fi
              sleep 1
            done
          ''
        else
          "host=${lib.escapeShellArg cfg.host}";

      dsh-web = pkgs.writeShellApplication {
        name = "dsh-web";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          jq
          tailscale
        ];
        text = ''
          ${resolveHost}

          if [ -z "$host" ]; then
            printf 'dsh-web: no Tailscale IPv4 address; refusing to start\n' >&2
            exit 1
          fi

          state_dir=${lib.escapeShellArg stateDir}
          url_file=${lib.escapeShellArg urlFile}
          mkdir -p "$state_dir"

          notify_discord() {
            local url=$1
            local webhook=''${DISCORD_WEBHOOK_URL:-}
            if [ -z "$webhook" ]; then
              printf 'dsh-web: DISCORD_WEBHOOK_URL is unset; skipping the startup notification\n' >&2
              return 0
            fi
            local payload
            payload=$(jq --compact-output --null-input \
              --arg content "$(hostname): dsh web 起動"$'\n'"<$url>" \
              '{content: $content}')
            curl --fail-with-body --silent --show-error --max-time 15 \
              --header 'Content-Type: application/json' \
              --data "$payload" \
              "$webhook" >/dev/null \
              || printf 'dsh-web: Discord notification failed\n' >&2
          }

          publish_url() {
            local printed_url=$1
            local rest authority port token url
            rest=''${printed_url#*://}
            authority=''${rest%%/*}
            port=''${authority##*:}
            token=''${printed_url#*token=}
            token=''${token%%&*}
            case "$port" in
              *[!0-9]*) port="" ;;
            esac
            if [ -z "$port" ] || [ -z "$token" ] || [ "$token" = "$printed_url" ]; then
              printf 'dsh-web: cannot build the access URL from %s\n' "$printed_url" >&2
              return 0
            fi
            url="http://$host:$port/?token=$token"
            ( umask 077; printf '%s\n' "$url" > "$url_file.tmp" )
            mv "$url_file.tmp" "$url_file"
            notify_discord "$url" || true
          }

          trusted=(--trusted-host "$host")
          ${extraTrustedHosts}

          exec ${lib.getExe' dsh "dsh"} ${lib.escapeShellArg cfg.profile} \
            --no-open \
            --host "$host" \
            "''${trusted[@]}" \
            > >(
              while IFS= read -r line; do
                printf '%s\n' "$line"
                case "$line" in
                  "dsh web: http"*)
                    printed=''${line#dsh web: }
                    publish_url "''${printed%% *}"
                    ;;
                esac
              done
            )
        '';
      };
    in
    {
      options.llm.dsh.web = {
        enable = lib.mkEnableOption "the dsh web GUI served on the Tailscale network";

        profile = lib.mkOption {
          type = lib.types.str;
          default = if config.llm.dsh.agentsAnywhere.enable then "sandbox" else "web";
          description = ''
            DSH profile the web server boots. `sandbox` is the profile that
            carries the Agents Anywhere bridge.
          '';
        };

        host = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Address to bind. When null, the host's Tailscale IPv4 address is used.";
        };

        trustedHosts = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra host[:port] authorities the browser-trust fence accepts, such as a MagicDNS name.";
        };

        environmentFile = lib.mkOption {
          type = lib.types.str;
          default = "%h/.config/dsh/web.env";
          description = ''
            systemd EnvironmentFile read by the service. It carries
            DISCORD_WEBHOOK_URL for the startup notification and any model
            credentials such as DEEPSEEK_API_KEY.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        home.packages = [ dsh ];

        systemd.user.services.dsh-web = {
          Unit = {
            Description = "DeepSeek Harness Web GUI on the Tailscale network";
            After = [ "network-online.target" ];
            Wants = [ "network-online.target" ];
          };
          Service = {
            Type = "simple";
            ExecStart = lib.getExe' dsh-web "dsh-web";
            Environment = [
              "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
            ];
            EnvironmentFile = "-${cfg.environmentFile}";
            Restart = "always";
            RestartSec = "5s";
            WorkingDirectory = "%h";
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
    };
}
