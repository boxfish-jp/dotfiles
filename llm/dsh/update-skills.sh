set -euo pipefail

base=""
for candidate in "$PWD" "$(git rev-parse --show-toplevel 2>/dev/null || true)"; do
  if [ -n "$candidate" ] && [ -f "$candidate/llm/dsh/_remote-skills.nix" ]; then
    base="$candidate"
    break
  fi
done

if [ -z "$base" ]; then
  echo "dsh-skills-update: llm/dsh/_remote-skills.nix が見つかりません。dotfiles の flake 内で実行してください。" >&2
  exit 1
fi

table="$base/llm/dsh/_remote-skills.nix"
current="$(nix-instantiate --eval --strict --json "$table")"
mapfile -t names < <(printf '%s' "$current" | jq -r 'keys[]')

out="$(mktemp)"
trap 'rm -f "$out"' EXIT

{
  echo "# nix run .#dsh-skills-update が rev/hash を埋める GitHub 取得スキルの表。"
  echo "# スキルを足すときは owner/repo/branch だけ書いて、このコマンドを実行する。"
  echo "# 1つのリポジトリに複数の SKILL.md があれば、その分だけ登録される。"
  echo "{"
} >"$out"

for name in "${names[@]}"; do
  owner="$(printf '%s' "$current" | jq -r --arg name "$name" '.[$name].owner')"
  repo="$(printf '%s' "$current" | jq -r --arg name "$name" '.[$name].repo')"
  branch="$(printf '%s' "$current" | jq -r --arg name "$name" '.[$name].branch // "main"')"
  current_rev="$(printf '%s' "$current" | jq -r --arg name "$name" '.[$name].rev // ""')"
  current_hash="$(printf '%s' "$current" | jq -r --arg name "$name" '.[$name].hash // ""')"

  if [ -z "$owner" ] || [ -z "$repo" ]; then
    echo "dsh-skills-update: $name に owner/repo が揃っていません" >&2
    exit 1
  fi

  if ! latest="$(
    git ls-remote "https://github.com/$owner/$repo" "refs/heads/$branch" | awk 'NR == 1 { print $1 }'
  )"; then
    echo "dsh-skills-update: $name の $branch を取得できませんでした" >&2
    exit 1
  fi

  if [ -z "$latest" ]; then
    echo "dsh-skills-update: $name の $branch を取得できませんでした" >&2
    exit 1
  fi

  if [ "$latest" = "$current_rev" ] && [ -n "$current_hash" ]; then
    echo "dsh-skills-update: $name は最新です ($latest)" >&2
    rev="$current_rev"
    hash="$current_hash"
  else
    if [ -z "$current_rev" ]; then
      echo "dsh-skills-update: $name を追加します ($latest)" >&2
    else
      echo "dsh-skills-update: $name $current_rev -> $latest" >&2
    fi

    if ! prefetched="$(
      nix-prefetch-url --unpack --print-path --type sha256 "https://github.com/$owner/$repo/archive/$latest.tar.gz"
    )"; then
      echo "dsh-skills-update: $name のソースを取得できませんでした" >&2
      exit 1
    fi

    hash32="$(printf '%s\n' "$prefetched" | head -n 1)"
    if ! hash="$(nix hash convert --to sri --hash-algo sha256 "$hash32")"; then
      echo "dsh-skills-update: $name のハッシュを SRI に変換できませんでした" >&2
      exit 1
    fi

    rev="$latest"
  fi

  {
    printf '  "%s" = {\n' "$name"
    printf '    owner = "%s";\n' "$owner"
    printf '    repo = "%s";\n' "$repo"
    printf '    branch = "%s";\n' "$branch"
    printf '    rev = "%s";\n' "$rev"
    printf '    hash = "%s";\n' "$hash"
    printf '  };\n'
  } >>"$out"
done

echo "}" >>"$out"

if cmp -s "$out" "$table"; then
  echo "dsh-skills-update: $table は最新です" >&2
else
  install -m 0644 "$out" "$table"
  echo "dsh-skills-update: $table を更新しました" >&2
  echo "dsh-skills-update: 反映には nrs と dsh の再起動が必要です" >&2
fi
