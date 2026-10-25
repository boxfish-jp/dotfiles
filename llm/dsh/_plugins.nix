{
  inputs,
  lib,
}:
let
  pluginRoot = ./plugins;
  depsFile = ./_deps.nix;
  depsHashes = if builtins.pathExists depsFile then import depsFile else { };

  pluginNames = builtins.attrNames (
    lib.filterAttrs (
      name: type:
      type == "directory"
      && !(lib.hasPrefix "_" name)
      && !(lib.hasPrefix "." name)
      && builtins.pathExists (pluginRoot + "/${name}/package.json")
    ) (builtins.readDir pluginRoot)
  );

  sourceFor =
    name:
    let
      dir = pluginRoot + "/${name}";
      ignored = lib.filter builtins.pathExists [
        (dir + "/node_modules")
        (dir + "/dist")
      ];
    in
    if ignored == [ ] then dir else lib.fileset.difference dir (lib.fileset.unions ignored);

  packageFor =
    pkgs: name:
    let
      dir = pluginRoot + "/${name}";
      manifest = builtins.fromJSON (builtins.readFile (dir + "/package.json"));
      depsHash = depsHashes.${name} or null;
    in
    inputs.nix-node-build.lib.mkNodeApp {
      inherit pkgs;
      pname = "dsh-plugin-${name}";
      version = manifest.version or "0.0.0";
      src = sourceFor name;
      depsHash =
        if depsHash != null then
          depsHash
        else
          throw ''
            dsh plugin "${name}" has no depsHash yet.
            Run `nix run .#dsh-plugins-update` (npm) or set depsHash in llm/dsh/_deps.nix.
          '';
      meta.description = manifest.description or "DSH plugin ${name}";
    };

  updateScript =
    pkgs:
    pkgs.writeShellApplication {
      name = "dsh-plugins-update";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.git
        pkgs.gnugrep
        pkgs.prefetch-npm-deps
      ];
      text = ''
        export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

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
        target="$base/llm/dsh/_deps.nix"
        tmp="$(mktemp)"
        trap 'rm -f "$tmp"' EXIT

        {
          echo "# \`nix run .#dsh-plugins-update\` が生成する depsHash の表。手で編集しないこと。"
          echo "{"
        } > "$tmp"

        found=0
        for dir in "$plugins"/*/; do
          [ -d "$dir" ] || continue
          name="$(basename "$dir")"
          case "$name" in _* | .*) continue ;; esac
          [ -f "$dir/package.json" ] || continue

          lock="$dir/package-lock.json"
          if [ ! -f "$lock" ]; then
            echo "dsh-plugins-update: $name に package-lock.json が無いので飛ばします（depsHash は _deps.nix に手で設定してください）" >&2
            continue
          fi

          echo "dsh-plugins-update: $name のハッシュを計算中..." >&2
          hash="$(prefetch-npm-deps "$lock" | tail -n 1)"
          if [ -z "$hash" ]; then
            echo "dsh-plugins-update: $name のハッシュを取得できませんでした" >&2
            exit 1
          fi

          if printf '%s' "$name" | grep -Eq '^[A-Za-z_][A-Za-z0-9_-]*$'; then
            printf '  %s = "%s";\n' "$name" "$hash" >> "$tmp"
          else
            printf '  "%s" = "%s";\n' "$name" "$hash" >> "$tmp"
          fi
          found=$((found + 1))
        done

        printf '}\n' >> "$tmp"

        if [ "$found" -eq 0 ]; then
          echo "dsh-plugins-update: プラグインが見つかりませんでした" >&2
        fi

        if cmp -s "$tmp" "$target"; then
          echo "dsh-plugins-update: _deps.nix は最新です" >&2
        else
          install -m 0644 "$tmp" "$target"
          echo "dsh-plugins-update: $target を更新しました" >&2
        fi
      '';
    };
in
{
  packagesFor =
    pkgs:
    lib.listToAttrs (
      map (name: lib.nameValuePair "dsh-plugin-${name}" (packageFor pkgs name)) pluginNames
    );

  listFor = pkgs: map (packageFor pkgs) pluginNames;

  inherit updateScript;
}
