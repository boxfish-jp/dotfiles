{ lib, ... }:
let
  pluginRoot = ./plugins;

  # 生成ファイル。存在しなければ全プラグイン未計算として扱う。
  depsFile = ./_npm-deps.nix;
  npmDeps = if builtins.pathExists depsFile then import depsFile else { };

  pluginNames = builtins.attrNames (
    lib.filterAttrs (
      name: type:
      type == "directory"
      && !(lib.hasPrefix "_" name)
      && !(lib.hasPrefix "." name)
      && builtins.pathExists (pluginRoot + "/${name}/package.json")
    ) (builtins.readDir pluginRoot)
  );

  # 1 プラグインを評価する。enable = false なら null。
  pluginFor =
    pkgs: name:
    let
      dir = pluginRoot + "/${name}";
      metaFile = dir + "/_plugin.nix";
      meta = if builtins.pathExists metaFile then import metaFile { inherit lib pkgs; } else { };

      pkg = builtins.fromJSON (builtins.readFile (dir + "/package.json"));
      entry = meta.entry or "dist/index.js";
      dontBuild = meta.dontBuild or false;
      npmDepsHash = meta.npmDepsHash or npmDeps.${name} or null;

      # ローカルの node_modules と、Nix が生成する dist はビルド入力に含めない。
      # dontBuild = true のときは dist を配布物としてそのまま使う。
      ignoredInputs = lib.filter (path: builtins.pathExists path) (
        [ (dir + "/node_modules") ] ++ lib.optional (!dontBuild) (dir + "/dist")
      );

      src = lib.fileset.toSource {
        root = dir;
        fileset =
          if ignoredInputs == [ ] then dir else lib.fileset.difference dir (lib.fileset.unions ignoredInputs);
      };

      package = pkgs.buildNpmPackage {
        pname = "dsh-plugin-${name}";
        version = meta.version or pkg.version or "0.0.0";
        inherit src;

        npmDepsHash =
          if npmDepsHash != null then
            npmDepsHash
          else
            throw ''
              dsh plugin "${name}" has no npmDepsHash yet.
              Run `nix run .#dsh-plugins-update` from the flake root, then rebuild.
              (or set `npmDepsHash` in llm/dsh/plugins/${name}/_plugin.nix)
            '';

        npmBuildScript = meta.buildScript or "build";
        dontNpmBuild = dontBuild;

        # 読み込み先が存在しないまま home-manager switch を通過させない。
        postInstall = ''
          plugin_dir="$out/lib/node_modules/${pkg.name}"

          # 実行時依存が無い場合、npm prune が .package-lock.json だけ残す。
          if [ -d "$plugin_dir/node_modules" ] \
            && [ -z "$(find "$plugin_dir/node_modules" -mindepth 1 -type d -print -quit)" ]; then
            rm -rf "$plugin_dir/node_modules"
          fi

          test -f "$plugin_dir/${entry}" || {
            echo "dsh plugin ${name}: ${entry} was not produced by the build" >&2
            echo "check the \`files\` field of llm/dsh/plugins/${name}/package.json" >&2
            exit 1
          }
        '';

        meta = {
          description = "DSH plugin ${name}";
        };
      };

      # cordis の insert に渡す実パス。
      entryPath = "${package}/lib/node_modules/${pkg.name}/${entry}";
    in
    if !(meta.enable or true) then
      null
    else
      {
        inherit
          name
          entryPath
          package
          ;
        id = meta.id or name;
        config = meta.config or { };
      };

  pluginsFor = pkgs: builtins.filter (plugin: plugin != null) (map (pluginFor pkgs) pluginNames);

  # npmDepsHash を再計算して _npm-deps.nix を書き直す。
  # flake の評価に依存させないため、ハッシュ計算は prefetch-npm-deps に任せる。
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
        target="$base/llm/dsh/_npm-deps.nix"
        tmp="$(mktemp)"
        trap 'rm -f "$tmp"' EXIT

        {
          echo "# \`nix run .#dsh-plugins-update\` が生成する npmDepsHash の表。手で編集しないこと。"
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
            echo "dsh-plugins-update: $name に package-lock.json が無いので飛ばします" >&2
            continue
          fi

          echo "dsh-plugins-update: $name のハッシュを計算中..." >&2
          hash="$(prefetch-npm-deps "$lock" | tail -n 1)"
          if [ -z "$hash" ]; then
            echo "dsh-plugins-update: $name のハッシュを取得できませんでした" >&2
            exit 1
          fi

          # ディレクトリ名がそのまま Nix の識別子になる場合だけ引用符を省く。
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
          echo "dsh-plugins-update: _npm-deps.nix は最新です" >&2
        else
          install -m 0644 "$tmp" "$target"
          echo "dsh-plugins-update: $target を更新しました" >&2
        fi
      '';
    };
in
{
  flake.lib.mkDshPlugins =
    {
      pkgs,
      extraPatches ? [ ],
    }:
    let
      plugins = pluginsFor pkgs;

      # 1 つの JSON にまとめる。文字列補間でプラグインの store パスを埋め込むので
      # derivation がプラグインを参照し、GC で片方だけ消えることがない。
      # extraPatches はプラグイン以外の patch 行（skills など）。store パスを
      # 埋め込む場合は呼び出し側で "${...}" により文字列化しておくこと。
      # derivation をそのまま toJSON に渡すと attrset として展開されてしまう。
      overlay = pkgs.writeText "dsh-plugins-overlay.json" (
        builtins.toJSON (
          map (plugin: {
            insert = [
              {
                inherit (plugin) id config;
                name = plugin.entryPath;
              }
            ];
          }) plugins
          ++ extraPatches
        )
      );
    in
    {
      inherit plugins overlay;
    };

  perSystem =
    { pkgs, ... }:
    let
      plugins = pluginsFor pkgs;
      update = updateScript pkgs;
    in
    {
      # nix build .#dsh-plugin-<name> でビルド成果物を単体確認できる。
      packages = lib.listToAttrs (
        map (plugin: lib.nameValuePair "dsh-plugin-${plugin.name}" plugin.package) plugins
      );

      apps.dsh-plugins-update = {
        type = "app";
        program = lib.getExe update;
      };
    };
}
