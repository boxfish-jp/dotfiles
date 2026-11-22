---
name: pr-review-comments
description: GitHub プルリクエストのレビューコメント・レビュー本文・一般コメントを全件取得し、各スレッドの resolve 状態と outdated 状態を付けて一覧にする。未解決コメントの洗い出しやレビュー対応の確認で使う。コメントへの返信・resolve 操作・指摘の修正には使わない。
metadata:
  owner: "user"
  type: "Capability Uplift"
  assumptions: "認証済みの gh CLI と Python 3 が使えること"
  retirement: "GitHub API が REST でも resolve 状態を返し、ページネーション込みの全件取得をモデルが安定して扱えるようになったら"
---

# PR Review Comments

## When to apply

- プルリクエストのレビューコメントを「全部」取得したいとき
- 各コメントが resolve 済みか未解決かを確認したいとき
- レビュー対応漏れを洗い出したいとき

使わない:

- コメントへの返信、スレッドの resolve、レビューの投稿
- 指摘された内容の修正（別の作業として行う）

読み取り専用のスキルである。GitHub へ書き込まない。

## 重要な事実

1. REST の `pulls/{n}/comments` には resolve 状態が無い。GraphQL の `reviewThreads.isResolved` を使う。
2. REST の既定ページ Size は 30。`per_page=100` とページ巡回が必須で、1ページ目だけ見ると取りこぼす。
3. GraphQL も `first` に上限がある。`pageInfo.hasNextPage` と `endCursor` で巡回する。
4. 画像などバイナリファイルへのコメントは `line` が null になる。`path` で絞ると消えるので、null を許す。
5. `isResolved` と `isOutdated` は別の軸。両方を記録し、outdated な未解決スレッドも残す。
6. インラインコメント、レビュー本文（`pulls/{n}/reviews`）、一般コメント（`issues/{n}/comments`）は別物。「全部」には3種類が必要。

## 手順

1. 対象の `OWNER/REPO` と PR 番号を確定する。URL から取れる場合は推測せずそのまま使う。
2. スキル読み込み時に表示された base directory の `scripts/fetch_pr_comments.py` を実行する。

   ```bash
   python3 <base directory>/scripts/fetch_pr_comments.py OWNER/REPO NUMBER --out <出力先>
   ```

   `gh` がキャッシュへの書き込みで失敗する環境では、事前に `XDG_CACHE_HOME` を書き込み可能なディレクトリへ設定する。

3. 標準出力の件数と警告を確認する。`restInlineComments` と `graphqlInlineComments` が一致しない場合は取りこぼしなので、警告を読んで原因を潰す。
4. 未解決だけ見たいときは `--unresolved-only` を付ける。ただし最初に全件を取得し、その後で絞る。resolve 済みを最初から除外すると件数照合ができない。
5. 生成された Markdown と JSON を読み、レビュー本文と一般コメントも確認する。ここに「結果を書き直す」といった全体指示が入ることがある。

## 出力

- `<出力先>/<repo>-pr<n>-comments.json`：全メッセージと resolve / outdated 状態
- `<出力先>/<repo>-pr<n>-comments.md`：人間が読む一覧

Markdown は次の順で並ぶ。

1. 件数サマリ（REST 件数、GraphQL 件数、未解決・解決・outdated、レビュー本文数、一般コメント数）
2. レビューコメント（スレッド単位。`resolved=` と `outdated=` を明記）
3. レビュー本文
4. 一般コメント

## 完了条件

- インラインコメント、レビュー本文、一般コメントの3種類を取得している
- 全スレッドに `resolved` と `outdated` が付いている
- REST と GraphQL のインラインコメント件数が一致し、警告が出ていない
- 画像パスで `line` が null なコメントも一覧に含まれている
- GitHub への書き込みをしていない
