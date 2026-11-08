---
name: skill-authoring
description: スキル(SKILL.md)を新規作成する、既存スキルの構成を直すときに使う。DSH で動くスキルとして成立させるための、置き場所、name と description の書き方、frontmatter、本文の構成、分割、品質ゲート、廃止条件を扱う。コードや設定の実装そのもの、既存スキルを実行する作業、単発の調査や質問だけのときは使わない。
metadata:
  owner: boxfish
  type: Encoded Preference
  assumptions: DSH のローカルスキル（llm/skills → Nix bundle）を前提にする
  retirement: スキル作成・公開のワークフローが変わったとき
---

# Skill Authoring

一次情報は DSH の `dsh-skill-filesystem` / `dsh-tool-skill` / `dsh-skill` / `dsh-agent-instructions` / `dsh-compaction-tool-result-pruner` の README と実装。原型は Claude Code Ultimate Guide だが、互換性の根拠にはしない。

## When to apply

使う:

- `SKILL.md` を新規作成する
- 既存スキルの構成・frontmatter・description を直す
- スキルを共有・公開する前に点検する
- ある手順をスキルにすべきか、別の機構にすべきか迷っている

使わない:

- コード・設定・Nix の実装そのもの
- 既存スキルを実行して別の作業をする
- 単発の調査・質問
- `AGENTS.md` に置くと決まっている規則の文案作成・編集（どの機構に置くかの判断は対象）

## スキルにするかの判断

スキルは「name と description を常時見せ、本文は呼ばれたときだけ読む」仕組み。次のどれかに当たるなら別の機構にする。

| 必要なもの | 置き場所 |
|---|---|
| ほぼ毎セッション効く短い事実・規則 | `AGENTS.md` |
| 独立したコンテキスト・専用ツール・並列作業 | agent |
| 順序・前提条件・リトライ・停止条件の保証 | script / CI / DSH plugin / workflow |
| 型付きの外部サービス境界 | MCP server |
| 繰り返す判断・手順・チェックリスト | スキル |

判断はスキルに残し、保証は harness に移す。正しさが「必ずこの順で実行されること」「成果物が存在すること」「失敗したら止まること」に依存するなら、その部分はコード側に置く。

## スキルの2類型

| | Capability Uplift | Encoded Preference |
|---|---|---|
| 何をするか | モデルが安定してできないことを補う | モデルができることをチーム固有の順序で行う |
| 寿命 | モデルの向上で薄れる | ワークフローが有効な間は残る |
| 廃止の合図 | モデルが同じ仕事を安定してできるようになる | ワークフローが変わる・不要になる |

## 手順

### 1. 置き場所と対象を決める

| 置き場所 | 場所 |
|---|---|
| 個人 | `~/.dsh/skills/`（`$DSH_HOME/skills`） |
| プロジェクト | `<projectRoot>/.dsh/skills/`、`.agents/skills/` |
| このリポジトリ | `llm/skills/<name>/` → `llm/dsh/default.nix` の `skills = [ ../skills ]` → 生成される `@dsh-nix/skills` の `customSkillDirs`。置いただけでは discovery されず再ビルドが要る |

- discovery は root 直下の1階層だけ（`<root>/<name>/SKILL.md` か `<root>/<name>.md`）。`**/SKILL.md` は見ない
- 同名スキルは rank の**値が小さい** root が勝つ（100 が最優先、500 が最後）。敗者はモデルのカタログに出ない（警告は出るがモデルには届かない）。複数 root に同じ name を置かない
- 所有者・類型・前提・廃止条件は `metadata` に書く（書き込み可能な場所に作る場合だけ）。`scope` は書かない。置き場所はパスで決まる
- ダウンロードしたスキルは、全文・同梱スクリプト・`references/` を読む。DSH では frontmatter がツール権限を絞らないので、危険度は本文とスクリプトで判断する。レビューした版（commit / digest）は完了報告に含める。残す必要があるなら、書き込み可能な場所（リポジトリ側のノートか `metadata`）にだけ書く。nix store 配下には後から書き足せない

### 2. description を先に書く

DSH の routing は name と description だけ。`whenToUse` はカタログにも本文ラッパにも出ない。description は 500 文字以内（カタログは 500 文字で切る）。

- 何をするか
- どういう状況で使うか
- 隣接する別の作業がどこに行くか（アンチトリガー）

```yaml
# 悪い: 内部の説明で、いつ使うかが無い
description: データベーススキーマの検証ロジック

# 良い: 対象・トリガー・アンチトリガーが揃っている
description: PostgreSQL のスキーマ変更とクエリ変更を、インデックス・ロック・マイグレーション安全性の観点でレビューする。SQL マイグレーションとスロークエリ調査で使う。アプリケーション層の API 設計には使わない。
```

### 3. frontmatter を書く

DSH が読むのは次の6キーだけ。詳細は `references/frontmatter.md`。

- 必須: `name`、`description`
- 任意: `whenToUse`、`metadata`、`disable-model-invocation`、`user-invocable`
- それ以外（`allowed-tools`、`disallowed-tools`、`when_to_use`、`effort`、`model`、`paths`、`context`、`agent`、`hooks`）は無視され、警告も出ない
- `disableModelInvocation` などの旧 camelCase と不正な真偽値は、スキルごと捨てられる
- `name` は `^[a-z0-9]+(-[a-z0-9]+)*$`。ディレクトリ名と揃える（強制ではない）
- `disable-model-invocation: true` は、スキル自身が deploy / publish / 送信 / 削除 / commit など取り返しのつかない操作を実行するとき。ユーザー依頼の commit や Issue 起票を案内するだけのスキルは model-invocable のままでよい（本文で「依頼された時だけ実行する」と書く）
- `user-invocable: false` は背景知識向け（`/` メニューから外れ、モデルからは使える）
- `metadata` はモデルに渡らない。人間とツールのための情報

### 4. 本文を書く

必須の要素: When to apply（トリガーとアンチトリガー）、番号付きか分岐の手順、出力の形式（例かテンプレート）、完了条件。

守ること:

- 1スキル1責務。catch-all にしない
- TODO・プレースホルダを残さない
- 検出だけのスキルは冒頭で「検出のみ。修正しない」と宣言し、書き込み・commit をしない。修正するなら dry-run を付ける
- 対話で止めたくないスキルは本文で「質問せずに進める」と書く。ツール権限はスキルでは変えられない
- レンダリング後の tool result が 8192 文字未満（本文は余裕を見て 7000 文字以下）。超えると compaction 時に先頭 4096 + 末尾 1024 に切り詰められる。ラッパと base directory の分も含めて数える

### 5. 分割する

詳細は `references/` などに移し、本文からリンクして「いつ開くか」を書く。DSH はサブディレクトリを discovery しないが、ロード時に渡される base directory からの相対パスで読める。

```text
skill-name/
├── SKILL.md
├── references/
├── checklists/
├── examples/
└── scripts/
```

サブエージェントは、同じ preset なら同じ provider 構成を継承する。agent 側にスキルを列挙する設定は無く、本文は呼ばれたときだけ読まれる。ただしカタログは cwd に依存するので、子の cwd が違えば project スキルの集合は変わる。`skill` ツールが無い、またはカタログが空なら子は使えない（確かめるなら子に一覧を聞く）。

### 6. 品質ゲートを通す

`checklists/pre-publish.md` を上から確認する。DSH にスキル専用の validator は無い。機械的に見るのは次の7点。

1. `name` が `^[a-z0-9]+(-[a-z0-9]+)*$`
2. 必須キーが `name` と `description` だけ
3. 旧 camelCase の invocation キーが無い
4. `description` が 500 文字以内
5. レンダリング後の tool result が 8192 文字未満
6. 新しいセッションで `skill` ツールに name を渡すと本文が返る
7. `/name` でも同じ本文が挿入される

完了条件:

- 適用される項目を確認し、該当しない項目は N/A として分母から除く
- 未達は理由付きで報告する

「公開しない」の強制は散文では行わない。script か CI に置く。

### 7. 廃止条件を決める

スキルの中に書き込むのではなく、作成時に決めて完了報告に含める。スキルを書き込み可能な場所（リポジトリ側）に作る場合だけ `metadata.retirement` にも残せる。nix store 配下のスキルには後から書き足せない。

- Capability Uplift: モデルが同じ仕事を安定してできるようになったら廃止（outgrowth）
- Encoded Preference: ワークフローが変わったら廃止。モデルの向上では廃止しない
- 廃止するときは、まずカタログから外す。このリポジトリでは `llm/skills/archive/<name>/` に移す（1階層 discovery の外なので見えなくなる）か、`llm/dsh/default.nix` の `skills` にフィルタを足して1件だけ除外する。`skills = [ ../skills ]` はルート単位なので、リストから1件だけ消すことはできない。`/nix/store` 配下は移動も削除もできない
- DSH にスキル別の起動履歴・context cost は無い。確認するなら `$DSH_HOME/sessions`（既定 `~/.dsh/sessions`）の記録を読む。スキル側からは何も書き込まない

## アンチパターン

- `my-skill-v2/` を併置する。版は中身（`tool-versions/v1.21/`）で分ける
- 起動したことを品質の証拠にする
- 存在しないキー（`allowed-tools`、`effort` など）を書く
- 一時的な指示を `AGENTS.md` に足す
- 文章でゲートを書いて、守られることを期待する

## 出力

```markdown
## 作ったスキル
- ファイル: <実際に作ったパス>
- 所有者: <name> / 類型: <Capability Uplift | Encoded Preference>
- 前提: <metadata.assumptions>
- description: <トリガー> / アンチトリガー: <どこでは使わないか>
- 品質ゲート: <通過数>/<適用項目>（N/A: <あれば>、未達: <あれば>）
- 版: <commit / digest（ダウンロードしたスキルの場合）>
- 廃止の合図: <何が起きたら消すか>
```

## 完了条件

- 適用されるチェックリスト項目を確認し、N/A を除いた分母と通過数を報告した
- 未達がある場合、理由を添えた
- 作成・変更したスキルを、再ビルド後の新しいセッションで `skill` ツールと `/name` の両方から引けることを確認した（`disable-model-invocation: true` は `/name` だけ）。確認できない場合は未検証と書いた
- 廃止の合図を報告に含めた

## 参照

- `references/frontmatter.md` — DSH が読むキーと無視するキー、落とし穴
- `references/design-patterns.md` — 複数エージェント、入力分岐、二層、版追随などの失敗モード別パターン
- `checklists/pre-publish.md` — 公開前チェックリスト
