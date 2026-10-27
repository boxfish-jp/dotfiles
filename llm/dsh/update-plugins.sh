# `nix run .#dsh-plugins-update` の本体。
# - llm/dsh/plugins/*/package-lock.json -> llm/dsh/_deps.nix
# - llm/dsh/_remote.nix の GitHub 取得プラグイン -> 最新タグの rev / hash / depsHash
#
# GitHub のプラグインを足すときは _remote.nix に owner と repo だけ書いて実行する。
# 残りのフィールドはここで最新タグから埋まる。

base=""
for candidate in "$PWD" "$(git rev-parse --show-toplevel 2>/dev/null || true)"; do
  if [ -n "$candidate" ] && [ -d "$candidate/llm/dsh/plugins" ]; then
    base="$candidate"
    break
  fi
done

if [ -z "$base" ]; then
  echo "dsh-plugins-update: llm/dsh/plugins が見つかりません。dotfiles の flake 内で実行してください。" >&2
  exit 1
fi

plugins="$base/llm/dsh/plugins"
deps_file="$base/llm/dsh/_deps.nix"
remote_file="$base/llm/dsh/_remote.nix"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

deps_out="$work/_deps.nix"
remote_out="$work/_remote.nix"

# ソースの lockfile からパッケージマネージャを判定する。
detect_package_manager() {
  directory=$1
  if [ -f "$directory/pnpm-lock.yaml" ]; then
    printf 'pnpm\n'
  elif [ -f "$directory/yarn.lock" ]; then
    if [ -f "$directory/.yarnrc.yml" ]; then
      printf 'yarn-berry\n'
    else
      printf 'yarn\n'
    fi
  else
    printf 'npm\n'
  fi
}

# ハッシュ計算は package-lock.json 前提なので、他のマネージャは黙って誤った値を
# 書き込まずに止める（pnpm / yarn 対応を入れるときはここから広げる）。
require_npm() {
  name=$1
  manager=$2
  if [ "$manager" != npm ]; then
    echo "dsh-plugins-update: $name は $manager です。このスクリプトのハッシュ計算はまだ npm 専用です。" >&2
    exit 1
  fi
}

{
  echo "# \`nix run .#dsh-plugins-update\` が生成する depsHash の表。手で編集しないこと。"
  echo "{"
} >"$deps_out"

found=0
for dir in "$plugins"/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  case "$name" in _* | .*) continue ;; esac
  [ -f "$dir/package.json" ] || continue

  manager="$(detect_package_manager "$dir")"
  require_npm "$name" "$manager"

  lock="$dir/package-lock.json"
  if [ ! -f "$lock" ]; then
    echo "dsh-plugins-update: $name に package-lock.json が無いので飛ばします（depsHash は _deps.nix に手で設定してください）" >&2
    continue
  fi

  echo "dsh-plugins-update: $name のハッシュを計算中..." >&2
  # ビルドと同じ正規化をかけた package.json / lock からハッシュを作る。
  # 素の lock で計算すると depsHash がビルド時の内容とずれる。
  normalized="$work/local-$name"
  mkdir -p "$normalized"
  cp "$dir/package.json" "$normalized/package.json"
  cp "$lock" "$normalized/package-lock.json"
  normalize_dual_dependencies "$normalized"
  hash="$(prefetch-npm-deps "$normalized/package-lock.json" | tail -n 1)"
  if [ -z "$hash" ]; then
    echo "dsh-plugins-update: $name のハッシュを取得できませんでした" >&2
    exit 1
  fi

  if printf '%s' "$name" | grep -Eq '^[A-Za-z_][A-Za-z0-9_-]*$'; then
    printf '  %s = "%s";\n' "$name" "$hash" >>"$deps_out"
  else
    printf '  "%s" = "%s";\n' "$name" "$hash" >>"$deps_out"
  fi
  found=$((found + 1))
done

printf '}\n' >>"$deps_out"

if [ "$found" -eq 0 ]; then
  echo "dsh-plugins-update: ローカルプラグインが見つかりませんでした" >&2
fi

if [ -f "$remote_file" ]; then
  {
    echo "# \`nix run .#dsh-plugins-update\` が生成する GitHub 取得プラグインの表。手で編集しないこと。"
    echo "{"
  } >"$remote_out"

  current="$(nix-instantiate --eval --strict --json "$remote_file")"
  mapfile -t remote_names < <(printf '%s' "$current" | jq -r 'keys[]')

  for name in "${remote_names[@]}"; do
    owner="$(printf '%s' "$current" | jq -r --arg name "$name" '.[$name].owner')"
    repo="$(printf '%s' "$current" | jq -r --arg name "$name" '.[$name].repo')"

    echo "dsh-plugins-update: $name の最新タグを確認中..." >&2
    tags="$( { git ls-remote --tags --refs "https://github.com/$owner/$repo" || true; } | awk '{print $2}' | sed 's|^refs/tags/||' || true)"
    tag="$(printf '%s\n' "$tags" | grep -E '^v?[0-9]+(\.[0-9]+)*$' | sort -V | tail -n 1 || true)"
    if [ -z "$tag" ]; then
      echo "dsh-plugins-update: $name のタグを取得できませんでした" >&2
      exit 1
    fi

    rev="$( { git ls-remote "https://github.com/$owner/$repo" "refs/tags/$tag^{}" || true; } | awk '{print $1}' | head -n 1 || true)"
    if [ -z "$rev" ]; then
      rev="$( { git ls-remote "https://github.com/$owner/$repo" "refs/tags/$tag" || true; } | awk '{print $1}' | head -n 1 || true)"
    fi
    if [ -z "$rev" ]; then
      echo "dsh-plugins-update: $name の $tag のリビジョンを取得できませんでした" >&2
      exit 1
    fi

    echo "dsh-plugins-update: $name $tag のソースを取得中..." >&2
    prefetched="$(nix-prefetch-url --unpack --print-path --type sha256 "https://github.com/$owner/$repo/archive/$rev.tar.gz")"
    src_hash32="$(printf '%s\n' "$prefetched" | head -n 1)"
    src_dir="$(printf '%s\n' "$prefetched" | tail -n 1)"
    src_hash="$(nix hash convert --to sri --hash-algo sha256 "$src_hash32")"

    manager="$(detect_package_manager "$src_dir")"
    require_npm "$name" "$manager"

    if [ ! -f "$src_dir/package-lock.json" ]; then
      echo "dsh-plugins-update: $name に package-lock.json がありません" >&2
      exit 1
    fi

    echo "dsh-plugins-update: $name の依存を取得中..." >&2
    normalize_dual_dependencies "$src_dir"
    cache="$work/cache-$name"
    NPM_FETCHER_VERSION=2 prefetch-npm-deps "$src_dir/package-lock.json" "$cache" >/dev/null
    deps_hash="$(nix hash path "$cache")"
    rm -rf "$cache"

    version="${tag#v}"
    {
      printf '  "%s" = {\n' "$name"
      printf '    version = "%s";\n' "$version"
      printf '    packageManager = "%s";\n' "$manager"
      printf '    owner = "%s";\n' "$owner"
      printf '    repo = "%s";\n' "$repo"
      printf '    rev = "%s";\n' "$rev"
      printf '    hash = "%s";\n' "$src_hash"
      printf '    depsHash = "%s";\n' "$deps_hash"
      printf '  };\n'
    } >>"$remote_out"
  done

  printf '}\n' >>"$remote_out"

  if cmp -s "$remote_out" "$remote_file"; then
    echo "dsh-plugins-update: _remote.nix は最新です" >&2
  else
    install -m 0644 "$remote_out" "$remote_file"
    echo "dsh-plugins-update: $remote_file を更新しました" >&2
  fi
fi

if cmp -s "$deps_out" "$deps_file"; then
  echo "dsh-plugins-update: _deps.nix は最新です" >&2
else
  install -m 0644 "$deps_out" "$deps_file"
  echo "dsh-plugins-update: $deps_file を更新しました" >&2
fi
