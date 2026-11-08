# 公開前チェックリスト

公開・共有・コミットの前に、上から確認して結果を完了報告に残す。該当しない項目は N/A と報告し、分母から除く。

DSH にスキル専用の validator は無い。次の7点は機械的に確認できる。

1. `name` が `^[a-z0-9]+(-[a-z0-9]+)*$`
2. 必須キーが `name` と `description` だけ
3. 旧 camelCase の invocation キー（`disableModelInvocation` など）が無い
4. `description` が 500 文字以内
5. レンダリング後の tool result が 8192 文字未満
6. 新しいセッションで `skill` ツールに name を渡すと本文が返る
7. `/name` でも同じ本文が挿入される

## 構造

- [ ] `SKILL.md` がある。`name` がディレクトリ名と一致する（DSH は強制しないが揃える）
- [ ] `name` が `^[a-z0-9]+(-[a-z0-9]+)*$`
- [ ] frontmatter のキーが `name` / `description` / `whenToUse` / `metadata` / `disable-model-invocation` / `user-invocable` の範囲に収まっている
- [ ] 無視されるキー（`allowed-tools`、`disallowed-tools`、`when_to_use`、`effort`、`model`、`paths`、`context`、`agent`、`background`、`arguments`、`argument-hint`、`shell`、`hooks`）を書いていない
- [ ] 旧 camelCase の invocation キーを書いていない（スキルごと drop される）
- [ ] `description` に「何を」「いつ」「どこでは使わないか」が入っている（全スキル）
- [ ] `description` が 500 文字以内。主要用途が先頭にある
- [ ] 取り返しのつかない操作（deploy / publish / 送信 / 削除 / commit）をスキル自身が実行するなら `disable-model-invocation: true`。ユーザー依頼の操作を案内するだけで、本文が「依頼された時だけ実行する」と定めているなら不要
- [ ] 背景知識だけのスキルは `user-invocable: false`
- [ ] レンダリング後の tool result が 8192 文字未満（本文は 7000 文字以下が目安）。詳細はサブファイルにあり、開く条件が本文に書かれている
- [ ] `skill` ツールと `/name` の両方で本文が返る（`disable-model-invocation: true` は `/name` だけ）

## 本文

- [ ] When to apply にトリガーとアンチトリガーが両方ある（全スキル）
- [ ] 手順が番号付きか判断の分岐になっている
- [ ] 出力の形式が書かれている。例かテンプレートがある（手順書でないスキルも短く書く）
- [ ] 完了条件（検証）が書かれている（手順書でないスキルも短く書く）
- [ ] 1責務。catch-all の dispatch になっていない
- [ ] TODO・プレースホルダ・未記入の節が無い
- [ ] 検出のみのスキルは冒頭で宣言し、書き込みをしない
- [ ] 対話で止めたくないスキルは、本文で「質問せずに進める」と書いてある（ツール権限はスキルでは変えられない）
- [ ] 保証が要る箇所（順序・必須成果物・停止）は script / CI / DSH plugin / workflow に逃がしてある
- [ ] 一時的な指示を `AGENTS.md` に足していない

## 所有者とライフサイクル

- [ ] 置き場所（個人 / プロジェクト / このリポジトリ）を決めた
- [ ] 所有者・類型・前提・廃止条件を `metadata` に書いた（書き込み可能な場所に作る場合だけ）。`scope` は書かない
- [ ] 類型に応じた廃止の合図を決め、完了報告に含めた
- [ ] ダウンロードしたスキルなら、全文・同梱スクリプト・`references/` を読み、レビューした版（commit / digest）を完了報告に含めた（残すなら書き込み可能な場所にだけ記録した）
- [ ] 同名スキルを複数の discovery root に置いていない
- [ ] discovery 対象 root に休眠スキルを残していない

## 出典

- `dsh-skill-filesystem/README.md`（Skill format / Roots and priority）
- `dsh-tool-skill/README.md`（カタログと description の上限）
- `dsh-compaction-tool-result-pruner/README.md`（本文の切り詰め）
- `dsh-agent-instructions/README.md`（`AGENTS.md` / `CLAUDE.md`）
