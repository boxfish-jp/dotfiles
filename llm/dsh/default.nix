{
  inputs,
  lib,
  ...
}:
let
  dshHomeRel = ".config/dotfiles/llm/dsh";

  # homeModules 側と perSystem（dsh-overlay）側で同じパッチ内容を使うための共有 let。
  # hookRunner は bun で hooks/<name>.ts を実行するラッパー。
  mkDshConfigLayer =
    pkgs:
    let
      dshHome = "${builtins.getEnv "HOME"}/${dshHomeRel}";

      hookRunner =
        name:
        pkgs.writeShellApplication {
          name = "dsh-hook-${name}";
          runtimeInputs = [ pkgs.bun ];
          text = ''exec bun "${dshHome}/hooks/${name}.ts"'';
        };

      hookCommand = name: "${hookRunner name}/bin/dsh-hook-${name}";

      hooksConfig = pkgs.writeText "dsh-hooks.json" (
        builtins.toJSON {
          hooks = {
            PreToolUse = [
              {
                matcher = "bash";
                hooks = [
                  {
                    type = "command";
                    command = hookCommand "pre_tool_use";
                  }
                ];
              }
            ];
            PostToolUse = [
              {
                matcher = "bash";
                hooks = [
                  {
                    type = "command";
                    command = hookCommand "post_tool_use";
                  }
                ];
              }
            ];
            Stop = [
              {
                hooks = [
                  {
                    type = "command";
                    command = hookCommand "stop";
                  }
                ];
              }
            ];
          };
        }
      );

      # ホームレベルのパッチ層（$DSH_HOME/cordis.patch.yml）。
      # ブンドル層 → プロファイル層(cordis.patch.yml) → ホーム層 → --patch の順で適用される。
      #
      # 注意:
      # - `permission` のプリセット3種は dsh-base バンドルが同一内容で定義済みなので
      #   ここでは上書きしない（base が変わったら追随させる）。
      # - スキルはここではなく $DSH_HOME/skills（skill-filesystem の既定ルート
      #   "user-dsh"）から発見させる。web バンドルは host の skill-filesystem 行を
      #   disabled し、preset 行に埋め込んだ skill-filesystem でスキャンするため、
      #   ユーザーパッチから customSkillDirs を差し込むには preset-standard の
      #   config.plugins 全体を再掲することになりブンドル更新と衝突しやすい。
      # - policy-hooks は `insert:` で新規行として挿入する。id 指定の素のエントリは
      #   既存行の上書き専用なので、バンドルに無いプラグインは insert が必須。
      # - @deepseek-ai/dsh-hooks-claude-code は nix の dsh インストールに同梱済み
      #   （store 内 node_modules から解決される）なので pnpm install は不要。
      cordisPatch = pkgs.writeText "cordis.patch.yml" ''
        - insert:
            - id: policy-hooks
              name: '@deepseek-ai/dsh-hooks-claude-code'
              config:
                configPath: ${hooksConfig}
      '';
    in
    {
      inherit
        dshHome
        hooksConfig
        cordisPatch
        ;
    };
in
{
  perSystem =
    { pkgs, system, ... }:
    let
      layer = mkDshConfigLayer pkgs;
    in
    {
      packages.dsh =
        let
          base = inputs.llm-agents.packages.${system}.dsh;
        in
        pkgs.writeShellScriptBin "dsh" ''
          export DSH_HOME="''${DSH_HOME:-$HOME/${dshHomeRel}}"
          if [ "$#" -eq 0 ]; then
            set -- web
          fi
          exec ${lib.getExe base} "$@"
        '';

      # 一時的適用用オーバレイ:
      #   ln -sfn ~/dotfiles/llm/opencode/skills ~/dotfiles/llm/dsh/skills   # スキル（初回のみ）
      #   nix run .#dsh -- web --patch "$(nix build --no-link --print-out-paths .#dsh-overlay)/cordis.patch.yml"
      # hooks/*.ts は $DSH_HOME/hooks（= ワークツリー）を直接参照するので、
      # overlay のフック設定はこのマシン上の実体パスで完結する。
      packages.dsh-overlay = pkgs.runCommand "dsh-overlay" { } ''
        mkdir -p "$out"
        cp ${layer.cordisPatch} "$out/cordis.patch.yml"
        cp ${layer.hooksConfig} "$out/dsh-hooks.json"
      '';
    };

  flake.homeModules.dsh =
    { config, pkgs, ... }:
    let
      dshHome = "${config.home.homeDirectory}/${dshHomeRel}";
      layer = mkDshConfigLayer pkgs;
    in
    {
      home.packages = [ pkgs.llm-agents.dsh ];

      home.sessionVariables.DSH_HOME = dshHome;

      # nix 管理のホームパッチ。DSH はこのパスへ書き戻さない（プロファイル root
      # cordis.yml だけが DSH 所有）なので symlink のまま安全。
      home.file."${dshHomeRel}/cordis.patch.yml".source = layer.cordisPatch;

      # opencode スキルを DSH の既定スキルルート経由で認識させる。
      # skill-filesystem は dshHome が symlink でも resolveDshHome で解決するため、
      # ~/.agents/skills と違い二重展開は起きない。リンク先は git ワークツリーの実体
      # （store コピーだと skills 配下の相対参照や将来の共有 lib 追加で壊れやすい）。
      home.file."${dshHomeRel}/skills".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${dshHomeRel}/../opencode/skills";
    };
}
