---
name: commit-style
description: git commit を実行する、コミットメッセージを書く・修正する時に必ずロードする。Triggered by keywords like "commit", "コミット", "git commit", "amend", "push".
---

# Commit Style

## いつコミットするか

- ユーザーにコミットを依頼された時だけ `git commit` を実行する。作業完了・テスト成功・編集の区切りはコミットの許可ではない
- 依頼が無いままcommit を行わない。迷ったらコミットせず報告する

## 形式

```
<type>: <件名>
```

- 1行の件名のみ。本文（変更の詳細・箇条書き・前後比較・動機の説明）は書かない
- type・scope はセマンティックコミットメッセージ (Conventional Commits) に従う

## 件名

- 日本語の平体。句点なし
- 何をしたかが1つ言えること。

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
