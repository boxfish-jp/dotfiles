{
  inputs,
  lib,
  self,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      base = inputs.llm-agents.packages.${system}.dsh;

      # スキルは llm/skills を store にコピーし、そのパスを dsh 側の設定
      # （skill-filesystem の customSkillDirs）へ書き込む。~/.dsh/skills に
      # リンクする代わりに、--patch で設定値として渡す。
      skillsDir = lib.fileset.toSource {
        root = ../skills;
        fileset = ../skills;
      };

      # web プロファイルでは base の host 行 `skill-filesystem` が web-app に
      # よって disabled にされ、探索はプリセット側の行が担う。既存行の上書きは
      # 効かないので、別 id / 別 providerName の provider を 1 本足して
      # レジストリの global レイヤ（全エージェント共通）に登録させる。
      # includeDefaultRoots = false で store のスキルだけを見る。
      # customSkillDirs は store パスを文字列として受け取る（plugins.nix 参照）。
      skillsPatch = {
        insert = [
          {
            id = "skill-dotfiles";
            name = "@deepseek-ai/dsh-skill-filesystem";
            config = {
              providerName = "dotfiles";
              includeDefaultRoots = false;
              customSkillDirs = [ "${skillsDir}" ];
            };
          }
        ];
      };

      # Auto-discovered plugins under llm/dsh/plugins/* (see plugins.nix).
      pluginSet = self.lib.mkDshPlugins {
        inherit pkgs;
        extraPatches = [ skillsPatch ];
      };

      tui = import ./tui/_package.nix { inherit lib pkgs base; };

      # `--patch` takes effect after the profile name, so insert it there.
      dsh = pkgs.writeShellScriptBin "dsh" ''
        case "''${1:-}" in
          "" | plugin | --help | --version | -h | -V)
            exec ${lib.getExe base} "$@"
            ;;
          --profile)
            exec ${lib.getExe base} "$1" "$2" --patch ${pluginSet.overlay} "''${@:3}"
            ;;
          --profile=*)
            exec ${lib.getExe base} "$1" --patch ${pluginSet.overlay} "''${@:2}"
            ;;
          -*)
            exec ${lib.getExe base} "$@"
            ;;
          *)
            exec ${lib.getExe base} "$1" --patch ${pluginSet.overlay} "''${@:2}"
            ;;
        esac
      '';
    in
    {
      packages = {
        dsh = dsh;
        dsh-tui = tui.package;
        dsh-tui-profile = tui.profile;
      };
    };

  flake.homeModules.dsh =
    {
      pkgs,
      self,
      ...
    }:
    let
      tuiPackage = self.packages.${pkgs.system}.dsh-tui;
      tuiProfile = self.packages.${pkgs.system}.dsh-tui-profile;
    in
    {
      home.packages = [
        self.packages.${pkgs.system}.dsh
        tuiPackage
      ];

      # dsh rewrites cordis.yml on every boot, so the profile cannot be a store symlink.
      home.activation.dshTuiProfile = ''
        profile_dir="$HOME/.dsh/profiles/dsh-tui"
        package_link="$profile_dir/node_modules/@deepseek-harness-tui/dsh-tui"

        mkdir -p "$(dirname "$package_link")"
        install -m 0644 ${tuiProfile}/package.json "$profile_dir/package.json"
        install -m 0644 ${tuiProfile}/pnpm-workspace.yaml "$profile_dir/pnpm-workspace.yaml"
        [ -e "$profile_dir/cordis.patch.yml" ] || install -m 0644 ${tuiProfile}/cordis.patch.yml "$profile_dir/cordis.patch.yml"
        [ -e "$profile_dir/cordis.yml" ] || printf '[]\n' > "$profile_dir/cordis.yml"

        rm -rf "$package_link"
        ln -s ${tuiPackage}/lib/node_modules/@deepseek-harness-tui/dsh-tui "$package_link"
      '';

      # スキルの読み込み先は ~/.dsh/skills へのリンクではなく、dsh の
      # skill-filesystem 設定（--patch で渡す customSkillDirs）で指定する。
      # 既定 root（~/.dsh/skills, ~/.agents/skills, プロジェクト配下）は
      # includeDefaultRoots により従来どおり有効。
    };
}
