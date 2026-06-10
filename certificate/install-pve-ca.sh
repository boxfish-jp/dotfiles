#!/usr/bin/env bash
set -euo pipefail

# 引数で証明書パスを指定可能（省略時はカレントディレクトリ）
CERT_SRC="${1:-./pve-root-ca.pem}"
DEST_DIR="/usr/local/share/ca-certificates"
DEST_PATH="${DEST_DIR}/pve-root-ca.crt"

# 前提チェック
if ! command -v sudo &>/dev/null; then
  echo "❌ Error: 'sudo' が必要です。" >&2; exit 1
fi
if [[ ! -f "$CERT_SRC" ]]; then
  echo "❌ Error: 証明書ファイル '$CERT_SRC' が見つかりません。" >&2
  echo "💡 Usage: $0 [path/to/pve-root-ca.pem]" >&2; exit 1
fi

echo "🔧 Proxmox Root CA をシステム信頼ストアに登録中..."
sudo mkdir -p "$DEST_DIR"
sudo cp "$CERT_SRC" "$DEST_PATH"
sudo chmod 644 "$DEST_PATH"

echo "🔄 CA バンドルを更新中..."
sudo update-ca-certificates

echo "✅ 登録完了。主要ツール(curl, apt, git, python等)が Proxmox 証明書を信頼します。"
