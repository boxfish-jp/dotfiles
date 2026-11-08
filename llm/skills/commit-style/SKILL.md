---
name: commit-style
description: git commit を実行する、コミットメッセージを書く・修正する、amend する、push する時に必ずロードする。1行の件名、type、amend/push の許可条件を扱う。Issue の文面には使わない。
metadata:
  owner: boxfish
  type: Encoded Preference
  assumptions: git のコミットメッセージと amend/push を対象にする
  retirement: コミットメッセージ規約が変わったとき
---

# Commit Style

## When to apply

使う:

- ユーザーに commit / amend / push を依頼されたとき
- コミットメッセージを書く・修正するとき

使わない:

- 依頼のない commit / amend / push
- Issue の文面（`issue-style`）

## いつコミットするか

- ユーザーにコミットを依頼された時だけ `git commit` を実行する。`amend` と `push` も同じ
- 依頼が無いまま commit / amend / push を行わない。迷ったら実行せず報告する

## 形式

```
<type>: <件名>
```

- 1行の件名のみ。本文（変更の詳細・箇条書き・前後比較・動機の説明）は書かない
- type・scope はセマンティックコミットメッセージ (Conventional Commits) に従う。scope を使う場合は `<type>(<scope>): <件名>` とする

## 件名

- 日本語の常体。句点なし
- 何をしたかが1つ言えること

## amend

- `git commit --amend` は、ユーザーが明示的に amend を依頼した時だけ実行する
- メッセージは同じ形式にする。メッセージだけを変える場合も、対象のコミットと差分を確認する
- push 済みのコミットを amend しない。必要な場合はユーザーに確認し、force-push の可否を明示的に得る

## push

- push も、ユーザーが明示的に依頼した時だけ実行する
- push の前に branch と remote を確認する
- `--force` / `--force-with-lease` はユーザーが明示的に依頼した時だけ使う。force-with-lease を優先する
- 拒否や non-fast-forward が返ったら、そのまま報告する

## 例

```
feat: 方眼グリッドの辺横断をBus経由で自動登録
fix: 名前同値時に endpointId tie-break で単独 initiater を決定
refactor: NearbyConnectionsManager から確保状態機械を PresenceSecurer へ分離
```

## NG 例

```
feat: グリッド登録を追加

- Bus 経由に変更
- 旧実装の xxx を削除
- 影響: yyy
```

## 出力

- 1行のコミットメッセージ
- 実行した操作（commit / amend / push）、対象 branch、remote

## 完了条件

- 依頼された操作だけを実行した
- 件名は1行の常体で、句点と本文が無い
- push 済みの amend と force-push は、明示的な依頼がある
- push 後に対象 branch と結果を報告した
