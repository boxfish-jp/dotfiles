#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <URL> [output_filename]"
  echo "Example: $0 https://annict.com"
  echo "         $0 https://github.com gh_shortcut"
  exit 1
fi

URL="$1"
OUTPUT_NAME="${2:-}"

# 1. URL形式チェック
if ! [[ "$URL" =~ ^https?:// ]]; then
  echo "❌ Error: URL must start with http:// or https://"
  exit 1
fi

echo "🌐 Fetching metadata from $URL ..."
DOMAIN=$(echo "$URL" | sed -E 's|https?://||;s|/.*||')

# 2. HTML取得（タイムアウト15秒、SPA対策でUA偽装）
HTML=$(curl -sL -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" --max-time 15 --connect-timeout 5 "$URL" 2>/dev/null || echo "")

if [[ -z "$HTML" ]]; then
  echo "⚠️  Warning: Failed to fetch HTML. Using fallback values."
fi

# 3. タイトル抽出（改行を潰して単一行化→<title>抽出→トリム）
TITLE=$(echo "$HTML" | tr '\n' ' ' | sed -n 's/.*<title>\(.*\)<\/title>.*/\1/Ip' | head -n 1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -c 40)
TITLE="${TITLE:-$DOMAIN}"

# 4. アイコン抽出（rel="icon" or "shortcut icon" を探し、hrefを取得）
FAV_HREF=$(echo "$HTML" | tr '\n' ' ' | grep -oi '<link[^>]*rel=["'"'"'][^"'"'"]*icon[^"'"'"]*["'"'"'][^>]*>' | head -n 1 | grep -oi 'href=["'"'"'][^"'"'"']*["'"'"']' | sed "s/href=['\"]//;s/['\"]//")

if [[ "$FAV_HREF" == http* ]]; then
  ICON="$FAV_HREF"
elif [[ -n "$FAV_HREF" ]]; then
  # 相対パスを絶対パスに変換（先頭の/除去後、ドメインと結合）
  FAV_HREF="${FAV_HREF#/}"
  ICON="https://$DOMAIN/$FAV_HREF"
else
  # 取得失敗時は Google Favicon API にフォールバック（最も確実）
  ICON="https://www.google.com/s2/favicons?domain=$DOMAIN&sz=64"
fi

# 5. 出力ファイル名決定
if [[ -z "$OUTPUT_NAME" ]]; then
  SAFE_NAME=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | sed 's/_\+/_/g' | sed 's/^_//;s/_$//' | head -c 30)
  OUTPUT_NAME="${SAFE_NAME:-$DOMAIN}.sh"
else
  OUTPUT_NAME="${OUTPUT_NAME%.sh}.sh"
fi

# 6. スクリプト生成
cat > "$OUTPUT_NAME" << EOF
#!/usr/bin/env bash
# @vicinae.schemaVersion 1
# @vicinae.title 🔗 $TITLE
# @vicinae.mode silent
# @vicinae.icon $ICON
# @vicinae.description $TITLE のページを開きます

xdg-open "$URL"
EOF

chmod +x "$OUTPUT_NAME"
echo "✅ Created: $OUTPUT_NAME"
echo "📁 Move to: mv $OUTPUT_NAME ~/.local/share/vicinae/scripts/"
echo "💡 Vicinae で 'Reload Script Directories' を実行してください。"
