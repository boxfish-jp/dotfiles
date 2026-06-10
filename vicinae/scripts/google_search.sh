#!/usr/bin/env bash
# @vicinae.schemaVersion 1
# @vicinae.title google search
# @vicinae.icon 🔍
# @vicinae.argument1 { "type": "text", "placeholder": "検索キーワード", "percentEncoded": true }

QUERY="${1}"
[[ -z "$QUERY" ]] && { echo "検索キーワードを入力してください"; exit 1; }

SEARCH_URL="https://www.google.com/search?q=${QUERY}"
xdg-open "$SEARCH_URL"
