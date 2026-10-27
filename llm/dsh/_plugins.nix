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

  # npm で公開されているプラグインを GitHub の固定リビジョンから取得する。
  # ピンは `_remote.nix`（`nix run .#dsh-plugins-update` が生成）に置く。
  # lib/ を同梱済みなのでビルド工程は無く、依存は上流の package-lock.json どおり入れる。
  remotePlugins = lib.mapAttrsToList (name: spec: spec // { inherit name; }) (import ./_remote.nix);

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

  # npm は「dependencies と devDependencies の両方に書かれたパッケージ」を dev 扱いするため、
  # `--omit=dev` や `npm prune --omit=dev` で実行時依存が落ちる。dsh プラグインでは
  # それが import 失敗（entry が active にならない）として現れる。
  # 例: dsh-opencode-go は @deepseek-ai/dsh-brand を両方に記載しており、
  #     nix ビルドでこれが消えて `ERR_MODULE_NOT_FOUND` になっていた。
  # 依存を入れる前に package.json と lock を揃える（実体は共有スクリプト）。
  normalizeScript = builtins.readFile ./normalize-dual-dependencies.sh;

  # 正規化後の src。`npm ci` は src の lock と deps キャッシュの lock の一致を検査するので、
  # 依存キャッシュ（mkNodeApp が src から導出する）と同じ内容を渡す必要がある。
  normalizedSource =
    pkgs: name: src:
    pkgs.runCommand "dsh-plugin-${name}-src" { nativeBuildInputs = [ pkgs.jq ]; } ''
      ${normalizeScript}
      cp -a ${src}/. $out
      chmod -R u+w $out
      normalize_dual_dependencies $out
    '';

  # src は正規化のため導出値になるので、mkNodeApp は評価時にソースを読めない。
  # 元のソース（パス）からパッケージマネージャを判定して明示的に渡す。
  detectPackageManager =
    dir:
    if builtins.pathExists (dir + "/pnpm-lock.yaml") then
      "pnpm"
    else if builtins.pathExists (dir + "/yarn.lock") then
      (if builtins.pathExists (dir + "/.yarnrc.yml") then "yarn-berry" else "yarn")
    else
      "npm";

  packageFor =
    pkgs: name:
    let
      dir = pluginRoot + "/${name}";
      manifest = builtins.fromJSON (builtins.readFile (dir + "/package.json"));
      scripts = manifest.scripts or { };
      depsHash = depsHashes.${name} or null;
    in
    inputs.nix-node-build.lib.mkNodeApp {
      inherit pkgs;
      pname = "dsh-plugin-${name}";
      version = manifest.version or "0.0.0";
      src = normalizedSource pkgs name (sourceFor name);
      packageManager = detectPackageManager dir;
      # ビルド済みの lib/ を同梱するプラグインはビルド工程を持たない。
      buildScript = if scripts ? build then "build" else null;
      depsHash =
        if depsHash != null then
          depsHash
        else
          throw ''
            dsh plugin "${name}" has no depsHash yet.
            Run `nix run .#dsh-plugins-update` (npm) or set depsHash in llm/dsh/_deps.nix.
          '';
      pruneDev = true;
      meta.description = manifest.description or "DSH plugin ${name}";
    };

  remotePackageFor =
    pkgs: spec:
    inputs.nix-node-build.lib.mkNodeApp {
      inherit pkgs;
      pname = "dsh-plugin-${spec.name}";
      version = spec.version;
      src = normalizedSource pkgs spec.name (
        pkgs.fetchFromGitHub {
          inherit (spec) owner repo rev hash;
        }
      );
      packageManager = spec.packageManager or "npm";
      inherit (spec) depsHash;
      # lib/ を同梱済みで、リポジトリに build script が無い。
      buildScript = null;
      # ビルド工程が無いので、dev 依存はインストールしない。
      # 上流 lock（開発依存を含む）をそのまま使うため、packument も取得する v2 を使う。
      extraAttrs = {
        npmDepsFetcherVersion = 2;
        npmInstallFlags = [ "--omit=dev" ];
      };
      meta.description = "DSH plugin ${spec.name}";
    };

  updateScript =
    pkgs:
    pkgs.writeShellApplication {
      name = "dsh-plugins-update";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.curl
        pkgs.gawk
        pkgs.git
        pkgs.gnugrep
        pkgs.gnused
        pkgs.jq
        pkgs.nix
        pkgs.prefetch-npm-deps
      ];
      text =
        ''
          export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
        ''
        + normalizeScript
        + builtins.readFile ./update-plugins.sh;
    };
in
{
  packagesFor =
    pkgs:
    lib.listToAttrs (
      map (name: lib.nameValuePair "dsh-plugin-${name}" (packageFor pkgs name)) pluginNames
      ++ map (
        spec: lib.nameValuePair "dsh-plugin-${spec.name}" (remotePackageFor pkgs spec)
      ) remotePlugins
    );

  listFor =
    pkgs: map (packageFor pkgs) pluginNames ++ map (remotePackageFor pkgs) remotePlugins;

  inherit updateScript;
}
