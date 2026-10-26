#!/usr/bin/env bash
# @vicinae.schemaVersion 1
# @vicinae.title 🔗 DeepSeek Harness
# @vicinae.mode silent
# @vicinae.icon https://fe-static.deepseek.com/chat/favicon.svg
# @vicinae.keywords ["dsh", "deepseek", "harness"]
# @vicinae.description このPCの dsh Web GUI を開きます

url_file="$HOME/.local/state/dsh/web-url"

if [ ! -r "$url_file" ]; then
  echo "このPCの dsh は起動していません"
  exit 1
fi

xdg-open "$(cat "$url_file")"
