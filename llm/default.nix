{
  self,
  inputs,
  lib,
  ...
}:
let
  # opencode 設定ツリー
  opencodeConfigTree = lib.fileset.toSource {
    root = ./opencode;
    fileset = lib.fileset.unions [
      ./opencode/AGENTS.md
      ./opencode/cli.json
      ./opencode/opencode.jsonc
      # スキルは llm/skills に集約しており、opencode 側のリンクは現在無い。
      # 将来 skills/ を置いた場合もそのまま同梱できるよう maybeMissing にする。
      (lib.fileset.maybeMissing ./opencode/skills)
      (lib.fileset.maybeMissing ./opencode/themes)
    ];
  };
in
{
  perSystem =
    { pkgs, system, ... }:
    {
      # nix run .#opencode で設定込みの実行ができる。
      # opencode は起動時に設定ディレクトリへ書き込むため、store 直下を
      # OPENCODE_CONFIG_DIR にできず、毎回 writable なステージ先へ
      # 設定を同期してから起動する。
      packages.opencode =
        let
          base = inputs.llm-agents.packages.${system}.opencode2;
        in
        pkgs.writeShellScriptBin "opencode" ''
          set -eu
          stage="''${XDG_STATE_HOME:-$HOME/.local/state}/opencode-packaged"
          rm -rf "$stage"
          mkdir -p "$stage"
          cp -R ${opencodeConfigTree}/. "$stage/"
          chmod -R u+w "$stage"
          export OPENCODE_CONFIG_DIR="$stage"
          exec ${lib.getExe base} "$@"
        '';
    };

  flake.homeModules.llm =
    {
      config,
      self,
      ...
    }:
    {
      imports = [
        self.homeModules.dsh
        self.homeModules.dsh-web
      ];

      llm.dsh.web.enable = builtins.elem config.home.username [
        "boxfish"
        "laptop"
        "sandbox"
        "server"
      ];

      # スマホからのリモート操作は sandbox だけに用意する。
      llm.dsh.agentsAnywhere.enable = builtins.elem config.home.username [ "sandbox" ];

      xdg.configFile."opencode".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/llm/opencode";
    }

  ;
}
