# Agents Anywhere の DSH ブリッジ（npm の @agents-anywhere/dsh-bridge-next）を
# 上流リポジトリの固定リビジョンからビルドする。
#
# `dsh plugin add` は使わず、ビルド済みのプラグインツリーを mkDsh に渡す。
# ブリッジの `bundle-connector` はリポジトリ直下の `connector/` を同梱するため、
# ビルドディレクトリの隣（`../connector`）へ配置してから `yarn build` を走らせる。
{
  inputs,
  pkgs,
}:
let
  version = "2.1.0";
  rev = "4ccfe15e3358b657b6b958e49367c8541f9a3d43";

  # ブリッジのビルドはリポジトリ直下の connector/ を同梱するため、リポジトリ全体を固定する。
  source = pkgs.fetchgit {
    url = "https://github.com/anywhere-labs/Agents-Anywhere";
    inherit rev;
    hash = "sha256-PC+ATxFXt+hLNzpIvTASC9hObq2VFJbs5/EPb/McmkA=";
  };

  # 上流は lockfile をコミットしないため、このリポジトリで固定した yarn.lock を重ねる。
  #
  # ブリッジは DSH 本体のパッケージをいくつか import するが、peerDependencies には
  # 一部しか宣言していない。dsh は「宣言済みの peer」だけを本体のインストール先へ
  # 解決するため、不足分を peer として補ってからビルドする。
  src =
    pkgs.runCommand "agents-anywhere-bridge-src-${version}" { nativeBuildInputs = [ pkgs.jq ]; }
      ''
        cp -a ${source}/dsh-bridge-next $out
        chmod -R u+w $out
        cp ${./agents-anywhere.yarn.lock} $out/yarn.lock
        jq '.peerDependencies += {
          "@deepseek-ai/dsh-commands": ">=0.2.0-rc.1 <0.3.0-0",
          "@deepseek-ai/dsh-llm": ">=0.2.0-rc.1 <0.3.0-0",
          "@deepseek-ai/dsh-session": ">=0.2.0-rc.1 <0.3.0-0",
          "@deepseek-ai/dsh-session-title": ">=0.2.0-rc.1 <0.3.0-0"
        }' $out/package.json > $out/package.json.patched
        mv $out/package.json.patched $out/package.json
      '';
in
inputs.nix-node-build.lib.mkNodeApp {
  inherit pkgs;

  pname = "dsh-plugin-agents-anywhere-bridge";
  inherit version src;

  packageManager = "yarn-berry";

  # yarn.lock はプラットフォーム固有の optional 依存のハッシュを持たないため、
  # `yarn-berry-fetcher missing-hashes` の出力を渡す。
  yarnBerryMissingHashes = toString ./agents-anywhere.missing-hashes.json;

  depsHash = "sha256-JGDeQtN0OhITY0KaVW4JeSTNWwpVbmjOm09h/ZbxnGs=";

  preBuild = ''
    cp -a ${source}/connector ../connector
  '';

  pruneDev = true;

  # オフラインキャッシュ（.yarn）は実行時に不要で、プラグインツリーが 300MB 近く太る。
  postInstall = ''
    rm -rf $out/.yarn
  '';

  meta.description = "Agents Anywhere remote control bridge for DeepSeek Harness";
}
