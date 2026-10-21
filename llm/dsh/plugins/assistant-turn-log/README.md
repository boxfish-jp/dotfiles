# assistant-turn-log

1ターンが完了した時点で、最終アシスタント応答とメタデータを JSONL に1行追記する DSH Host プラグインです。

- トリガー: durable Session イベント `turn/end`（`session/event` 経由）
- 本文: そのターンで最後に確定した `assistant/message` の text ブロック
- サブエージェントは既定で除外
- 出力: `$DSH_HOME/assistant-turn-log/turns.jsonl`（`DSH_HOME` 未設定なら `~/.dsh/assistant-turn-log/turns.jsonl`）

## 設定

必要なら [_plugin.nix](./_plugin.nix) を作り、`config` に渡します（設定しない場合は何も作らなくて構いません）。

```nix
{ ... }:
{
  config = {
    outputPath = "/home/laptop/assistant-turns.jsonl";
    includeSubagents = false;
    includeEmpty = false;
    maxTextChars = 20000;
  };
}
```

| key | 型 | 既定 | 意味 |
|---|---|---|---|
| `outputPath` | string | `$DSH_HOME/assistant-turn-log/turns.jsonl` | 出力先の絶対パス |
| `includeSubagents` | boolean | `false` | サブエージェントも記録する |
| `includeEmpty` | boolean | `false` | 本文のないターンも記録する |
| `maxTextChars` | number | `20000` | 本文の上限。`0` は無制限 |

## ビルドとテスト

ビルドは Nix が行います。`llm/dsh/plugins.nix` が `buildNpmPackage` で
`npm ci` → `npm run build` を実行し、出来上がった `dist/` だけを store に置きます。
`dist/` はコミットしません（`.gitignore` 済み）。手元のビルドは型検査とテストの
ためだけのものです。

```sh
npm install
npm run typecheck
npm test
```

`package-lock.json` を更新したときだけ、npm 依存のハッシュを計算し直してください。

```sh
nix run .#dsh-plugins-update   # llm/dsh/_npm-deps.nix を更新
```

インストールは `llm/dsh/plugins.nix` の自動検出で行われます（`install_bundle` は不要）。
`home-manager switch` か `nix run .#dsh` で反映されます。`--patch` が参照するのは
`/nix/store/<hash>-dsh-plugin-assistant-turn-log-*/lib/node_modules/@local/dsh-assistant-turn-log/dist/index.js`
で、`plugins/` のツリー（src・test・tsconfig など）がそのまま store に入ることはありません。

ビルド成果物を単体で確認するには:

```sh
nix build .#dsh-plugin-assistant-turn-log
```

## レコード例

```json
{"time":1760000000000,"sessionId":"sess_...","turn":3,"seq":42,"reason":{"kind":"completed"},"cwd":"/home/laptop/work","provider":"opencode-go","model":"deepseek-v4.1-flash","interrupted":false,"assistantMessages":2,"toolCalls":3,"usage":{"inputTokens":1234,"outputTokens":567},"responseChars":321,"truncated":false,"response":"最終回答..."}
```
