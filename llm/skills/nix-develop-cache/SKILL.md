---
name: nix-develop-cache
description: Use when nix develop fails because only the workspace is writable (bwrap, agent sandbox, CI), e.g. "attempt to write a readonly database" in ~/.cache/nix. Triggered by keywords like "nix develop", "bwrap", "sandbox", "読み取り専用", "Read-only file system", "fetcher-cache".
---

# nix develop のキャッシュをワークスペースへ

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
