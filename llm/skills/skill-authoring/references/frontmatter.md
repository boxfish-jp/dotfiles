# DSH の SKILL.md frontmatter

一次情報: `dsh-skill-filesystem/README.md`（Skill format / Roots and priority）と `lib/index.js` の `parseSkillFile`、`dsh-tool-skill/README.md`、`dsh-compaction-tool-result-pruner/README.md`。

## DSH が読むキー

| キー | 必須 | 挙動 |
|---|---|---|
| `name` | 必須 | `^[a-z0-9]+(-[a-z0-9]+)*$`。長さ上限は無い。ディレクトリ名との一致は強制されないが、`/name` とプレビューの対応がずれるので揃える |
| `description` | 必須 | 空でなければ通る。長さ検証は無いが、カタログ描画は `catalogDescriptionMaxLength`（既定 500）で切られ、空白は正規化される。500 文字以内に収める |
| `whenToUse` | 任意 | provider metadata。カタログにも本文ラッパにも描画されない。routing は name と description だけで決まる |
| `metadata` | 任意 | 値は保持されるが、カタログにもロード結果にも出ない。人間とツール用。`owner` / `type` / `assumptions` / `retirement` を書き、`scope` は書かない（置き場所は discovery root で決まる） |
| `disable-model-invocation` | 任意 | `true` でモデル向けカタログと `skill` ツールから外れ、`/name` だけが入口になる。省略時は許可 |
| `user-invocable` | 任意 | `false` で `/` メニューから外れ、モデルからは使える。省略時は許可 |

真偽値は YAML の boolean と、大文字小文字を問わない `true`/`false`、`yes`/`no`、`on`/`off`、`1`/`0` を受ける。

## 無視されるキー

`allowed-tools`、`disallowed-tools`、`when_to_use`、`effort`、`model`、`paths`、`context`、`agent`、`background`、`arguments`、`argument-hint`、`shell`、`hooks`。

これらは Claude Code の拡張で、DSH は読みも警告もしない。書くと「設定したつもり」になるだけなので書かない。特に:

- `allowed-tools` / `disallowed-tools` はツール権限を変えない。権限はセッションの設定と承認で扱う
- `when_to_use` は `whenToUse` の誤り。DSH は無視する
- `effort` / `model` はスキル単位では指定できない。モデルと reasoning effort はセッションか agent preset 側で決める

## スキルごと捨てられる書き方

次のキーは旧名として拒否され、スキル全体がカタログから消える（警告が出るだけ）。

- `disableModelInvocation`
- `modelInvocable`
- `userInvocable`

真偽値の不正な綴り（`ture` など）も同じくスキルごと drop する。省略時は許可なので、迷ったら書かない。

## 本文のサイズ

- 本文自体にサイズ上限は無い
- ただし compaction 時に、**レンダリング後の tool result** が 8192 文字を超えると先頭 4096 + 末尾 1024 に切り詰められる（`thresholdChars` / `headChars` / `tailChars`）。本文に `<skill_content>` ラッパと base directory の案内が加わるので、本文だけを見て「8191 だから安全」とは言えない
- 目安として本文は 7000 文字以下にし、超える詳細は `references/` に置いて本文から開く条件を書く

## 壊れたスキルの見え方

frontmatter が不正、name が不正、invocation の値が不正なスキルは、警告を出してカタログから消える。モデル側には診断が出ないので、「無い」のか「壊れている」のか区別できない。作成時は上の7点（`SKILL.md` の手順6）で確認する。
