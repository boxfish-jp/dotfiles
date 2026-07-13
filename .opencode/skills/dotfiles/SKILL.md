---
name: dotfiles
description: >
  このリポジトリが管理するアプリ(ghostty, nvim, alacritty, zellij,
  fcitx5, kanata, git, bash, KDE Plasma, opencode, vicinae, pipewire,
  OBS, streaming-kit, DaVinci Resolve, Krita, Flatpak, qpwgraph)の
  設定変更について言及されたら必ずロードする。設定ファイルは
  ~/.config/dotfiles/<app>/ にあり、~/.config/<app>/ ではない。
---

## プロジェクト概要

- Nix flake 構成（NixOS + home-manager）
- 実パス: `~/.config/dotfiles/`
- 設定の変更は **直接システムの `~/.config/<app>/` ではなく、このリポジトリ内のディレクトリ** を編集する
- 3ホスト: `laptop` / `boxfish` / `server`
- 各アプリは `hosts/<host>/home.nix` で `imports = [ ../../<app> ]` として取り込む

## 設定ファイルの場所マッピング

| アプリ | 編集すべきパス |
|---|---|
| nvim | `~/.config/dotfiles/nvim/` |
| alacritty | `~/.config/dotfiles/alacritty/` |
| ghostty | `~/.config/dotfiles/ghostty/` |
| zellij | `~/.config/dotfiles/zellij/` |
| fcitx5 | `~/.config/dotfiles/fcitx5/` |
| kanata | `~/.config/dotfiles/kanata/` |
| git / lazygit | `~/.config/dotfiles/git/` |
| bash | `~/.config/dotfiles/bash/` |
| btop | `~/.config/dotfiles/btop/` |
| KDE Plasma | `~/.config/dotfiles/kde_plasma/` |
| opencode | `~/.config/dotfiles/llm/opencode/` |
| vicinae | `~/.config/dotfiles/vicinae/` |
| pipewire | `~/.config/dotfiles/pipewire/` |
| containers / podman | `~/.config/dotfiles/containers/` |
| OBS Studio | `~/.config/dotfiles/obs/` |
| streaming-kit | `~/.config/dotfiles/streaming/` |
| DaVinci Resolve | `~/.config/dotfiles/video_editor/` |
| Krita | `~/.config/dotfiles/paint/` |
| Flatpak | `~/.config/dotfiles/flatpak/` |
| qpwgraph | `~/.config/dotfiles/qpwgraph/` |

## ファイル構造
default.nixにはプラグインや外部からインポートするライブラリに関するが書かれていることが多い、その他のファイルは設定ファイルであることが多い。

