# npm は「dependencies と devDependencies の両方に書かれたパッケージ」を dev 扱いするため、
# `--omit=dev` や `npm prune --omit=dev` で実行時依存が落ちる。dsh プラグインでは
# それが import 失敗（entry が active にならない）として現れる。
# 例: dsh-opencode-go の @deepseek-ai/dsh-brand。
# 依存インストール前に runtime 側へ寄せ、package.json と lock を揃える。
normalize_dual_dependencies() {
  directory=$1
  [ -f "$directory/package.json" ] || return 0
  [ -f "$directory/package-lock.json" ] || return 0
  jq -e '.lockfileVersion >= 2' "$directory/package-lock.json" >/dev/null || return 0
  dualDependencies=$(
    jq -r '((.dependencies // {}) | keys) as $runtime
      | ((.devDependencies // {}) | keys) as $dev
      | ($runtime - ($runtime - $dev))[]' "$directory/package.json"
  )
  [ -n "$dualDependencies" ] || return 0
  printf '%s\n' "$dualDependencies" | while IFS= read -r dependency; do
    jq --arg name "$dependency" 'del(.devDependencies[$name])' \
      "$directory/package.json" >"$directory/package.json.normalized"
    mv "$directory/package.json.normalized" "$directory/package.json"
    jq --arg name "$dependency" '
      del(.packages[""].devDependencies[$name])
      | .packages["node_modules/\($name)"] = ((.packages["node_modules/\($name)"] // {}) + { dev: false })
    ' "$directory/package-lock.json" >"$directory/package-lock.json.normalized"
    mv "$directory/package-lock.json.normalized" "$directory/package-lock.json"
  done
}
