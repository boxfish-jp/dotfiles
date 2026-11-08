---
name: nix-develop-cache
description: nix develop が読み取り専用の HOME や sandbox で失敗するときに使う。`attempt to write a readonly database` など `~/.cache/nix` への書き込み失敗を、`NIX_CACHE_HOME` をワークスペースへ向けて回避する。通常の nix develop が動く環境や、キャッシュ以外が原因の失敗には使わない。Triggered by "nix develop", "bwrap", "sandbox", "読み取り専用", "Read-only file system", "fetcher-cache".
metadata:
  owner: boxfish
  type: Capability Uplift
  assumptions: nix flakes と読み取り専用 HOME の sandbox を前提にする
  retirement: nix が読み取り専用キャッシュを扱えるようになったとき、または sandbox の前提が変わったとき
---

# nix develop のキャッシュをワークスペースへ

## When to apply

使う:

- `nix develop` が `~/.cache/nix` への書き込みで失敗するとき
- bwrap / agent sandbox / CI で `$HOME` が読み取り専用のとき

使わない:

- 通常の `nix develop` が動く環境
- キャッシュ以外（評価エラー、依存取得）が原因の失敗

## 症状

`$HOME` が読み取り専用だと、flake の評価前に nix が `~/.cache/nix/fetcher-cache-v4.sqlite` へ
書こうとして落ちる。dev shell の shellHook はまだ実行されていないので、flake.nix では直せない。

```
error: ... attempt to write a readonly database
       (in '/home/.../.cache/nix/fetcher-cache-v4.sqlite')
```

## 対処

`NIX_CACHE_HOME` をワークスペースへ向けてから起動する。

```bash
[ -w "$HOME" ] || export NIX_CACHE_HOME="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.nix-cache"
nix develop
```

`nix develop --command ...` でも同じで、シェルに入る前（コマンド実行前）に渡す。

## 注意

- ホームが書き込める環境では設定しない。nix のキャッシュをプロジェクトごとに二重に持つことになる。
- `NIX_CACHE_HOME` を知らない古い nix では `XDG_CACHE_HOME` を使う。その場合は flutter や pub の
  キャッシュも一緒に移る。
- `.nix-cache/` を `.gitignore` に入れる。
- shellHook の中で `export NIX_CACHE_HOME=...` しても間に合わない。nix は flake を評価する時点で
  既にキャッシュを書くため、効くのは起動コマンド側だけ。

## 出力

- 実行するコマンド（`export NIX_CACHE_HOME=...` と `nix develop`）
- 追加した `.gitignore` の行

## 完了条件

- `nix develop` が起動した
- `.nix-cache/` を `.gitignore` に入れた
- ホームが書き込める環境では `NIX_CACHE_HOME` を設定していない
