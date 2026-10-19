{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.kimaki = pkgs.callPackage ./_package.nix { };

      apps.kimaki-update =
        let
          updateScript = pkgs.writeShellApplication {
            name = "kimaki-update";
            runtimeInputs = [
              pkgs.bun
              pkgs.jq
              pkgs.curl
              pkgs.nix
            ];
            text = ''
              set -euo pipefail

              # kimaki のバージョン・srcハッシュ・deps outputHash・bun.lockの同期を取る。
              # jq条件とmuslのrm一覧は_package.nixと同一に保つこと。
              registry="https://registry.npmjs.org/kimaki"
              pkg_nix=""
              base_dir=""

              find_files() {
                for d in "$(pwd)" "$(git rev-parse --show-toplevel 2>/dev/null || true)"; do
                  if [ -n "$d" ] && [ -f "$d/llm/kimaki/_package.nix" ]; then
                    base_dir="$d"
                    pkg_nix="$d/llm/kimaki/_package.nix"
                    return 0
                  fi
                done
                return 1
              }

              if ! find_files; then
                echo "kimaki-update: flake root is not detected; run this in the dotfiles flake" >&2
                exit 1
              fi

              fetch_latest() {
                curl --fail --silent --show-error --max-time 20 "''${registry}" | jq -r '."dist-tags".latest'
              }

              if ! latest=$(fetch_latest); then
                echo "kimaki-update: could not reach the npm registry; skipping kimaki update" >&2
                exit 0
              fi

              current=$(sed -n 's/^  version = "\(.*\)";$/\1/p' "$pkg_nix")

              if [ "$current" = "$latest" ]; then
                echo "kimaki-update: kimaki $current is up to date; syncing bun.lock anyway" >&2
              else
                echo "kimaki-update: ''${current} -> ''${latest}" >&2
              fi

              tarball="https://registry.npmjs.org/kimaki/-/kimaki-''${latest}.tgz"

              if ! src_hash=$(nix store prefetch-file --json "$tarball" | jq -r .hash); then
                echo "kimaki-update: failed to prefetch the source tarball; _package.nix left unchanged" >&2
                exit 1
              fi

              work_dir=$(mktemp -d)
              cleanup() {
                rm -rf "$work_dir"
              }
              trap cleanup EXIT

              curl --fail --silent --show-error --max-time 60 "$tarball" | tar -xz -C "$work_dir"
              proj_dir="$work_dir/package"
              cd "$proj_dir"

              jq 'del(.devDependencies)' package.json > .package.json
              mv .package.json package.json

              export HOME="$work_dir/home"
              mkdir -p "$HOME"
              export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

              # bunは--productionではlockfileを保存しないため、先にplainな
              # installでbun.lockを生成してからfrozen+productionでdeps
              # derivationと同一のnode_modulesに再構築する。
              if ! bun install --ignore-scripts --no-progress; then
                echo "kimaki-update: failed to regenerate bun.lock; _package.nix left unchanged" >&2
                exit 1
              fi

              if [ ! -s bun.lock ]; then
                echo "kimaki-update: generated bun.lock is empty; _package.nix left unchanged" >&2
                exit 1
              fi

              # bun.lock v2 は JSONC(trailing comma)なので jq では検査できず、
              # lockの整合性検査をfrozen installそのものに任せる
              if ! bun install --frozen-lockfile --production --ignore-scripts --no-progress; then
                echo "kimaki-update: frozen production install failed; _package.nix left unchanged" >&2
                exit 1
              fi

              rm -rf node_modules/@parcel/watcher-linux-x64-musl \
                     node_modules/@img/sharp-libvips-linuxmusl-x64 \
                     node_modules/@img/sharp-linuxmusl-x64

              deps_hash=$(nix hash path "$proj_dir")

              sed -i "s|^  version = \".*\";|  version = \"''${latest}\";|" "$pkg_nix"
              sed -i "s|^      hash = \"sha256-.*\";|      hash = \"''${src_hash}\";|" "$pkg_nix"
              sed -i "s|^    outputHash = \"sha256-.*\";|    outputHash = \"''${deps_hash}\";|" "$pkg_nix"

              if [ "$(sed -n 's/^  version = "\(.*\)";$/\1/p' "$pkg_nix")" != "$latest" ]; then
                echo "kimaki-update: _package.nix rewrite failed; verify the version/hash lines manually" >&2
                exit 1
              fi

              cp bun.lock "$base_dir/llm/kimaki/bun.lock"

              git -C "$base_dir" status --short || true
            '';
          };
        in
        {
          type = "app";
          program = "${updateScript}/bin/kimaki-update";
        };
    };

  flake.homeModules.kimaki =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.llm.kimaki;
      kimakiPkg = pkgs.callPackage ./_package.nix { };
    in
    {
      options.llm.kimaki.enable = lib.mkEnableOption "kimaki";

      config = lib.mkIf cfg.enable {
        home.packages = [ kimakiPkg ];

        systemd.user.services.kimaki = {
          Unit = {
            Description = "Kimaki — collaborative agent orchestrator via Discord";
            After = [ "network-online.target" ];
            Wants = [ "network-online.target" ];
          };
          Service = {
            Type = "simple";
            ExecStart = "${kimakiPkg}/bin/kimaki --data-dir %h/.local/share/kimaki";
            EnvironmentFile = "%h/.config/kimaki/.env";
            Restart = "on-failure";
            RestartSec = "5s";
          };
          Install = {
            WantedBy = [ "default.target" ];
          };
        };
      };
    }

  ;
}
