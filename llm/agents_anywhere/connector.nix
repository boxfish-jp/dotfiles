# Agents Anywhere の Connector CLI を systemd user service として常駐させる。
#
# Connector は Server との WebSocket を保持し、リモートからのシェル・ファイル・
# Agent 実行要求をローカルで処理する。止めるとデバイスが offline になるため常駐必須。
#
# 認証情報 (~/.agents-anywhere/connector.json) は `anywhere-cli configure` が
# 0600 で書き出したものをそのまま読む。token は Nix には入れない。
{
  self,
  ...
}:
{
  flake.homeModules.agents-anywhere-connector =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.agents-anywhere-connector;
    in
    {
      options.services.agents-anywhere-connector = {
        enable = lib.mkEnableOption "Agents Anywhere Connector CLI";

        version = lib.mkOption {
          type = lib.types.str;
          default = "2.1.0";
          description = "PyPI の anywhere-cli のバージョン。Server と同じ系列に合わせる。";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.user.services.agents-anywhere-connector = {
          Unit.Description = "Agents Anywhere connector (anywhere-cli)";

          Service = {
            ExecStart = "${pkgs.uv}/bin/uvx --python ${pkgs.python312}/bin/python3.12 anywhere-cli@${cfg.version} start";
            Environment = [ "UV_PYTHON_DOWNLOADS=never" ];
            Restart = "always";
            RestartSec = "5s";
          };

          Install.WantedBy = [ "default.target" ];
        };
      };
    };
}
