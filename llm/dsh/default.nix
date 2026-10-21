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
        set -e

        args=("$@")
        rest=()

        case "''${args[0]:-}" in
          "" | plugin | --help | --version | -h | -V)
            exec ${lib.getExe base} "''${args[@]}"
            ;;
          --profile)
            profile="''${args[1]:-}"
            rest=("''${args[@]:2}")
            ;;
          --profile=*)
            profile="''${args[0]#--profile=}"
            rest=("''${args[@]:1}")
            ;;
          -*)
            exec ${lib.getExe base} "''${args[@]}"
            ;;
          *)
            profile="''${args[0]}"
            rest=("''${args[@]:1}")
            ;;
        esac

        if [ -z "$profile" ]; then
          exec ${lib.getExe base} "''${args[@]}"
        fi

        if [ "$profile" = tui ]; then
          profile=dsh-tui
        fi

        if [ "$profile" = dsh-tui ] && [ "''${rest[0]:-}" != plugin ]; then
          ${tui.provision}
        fi

        exec ${lib.getExe base} "$profile" --patch ${pluginSet.overlay} "''${rest[@]}"
      '';
    in
    {
      packages = {
        dsh = dsh;
        dsh-tui = tui.launcher;
        dsh-tui-profile = tui.profile;
        dsh-tui-provision = tui.provision;
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
    in
    {
      home.packages = [
        self.packages.${pkgs.system}.dsh
        tuiPackage
      ];

      # dsh rewrites cordis.yml on every boot, so the profile cannot be a store symlink.
      home.activation.dshTuiProfile = "${self.packages.${pkgs.system}.dsh-tui-provision}";

      # スキルの読み込み先は ~/.dsh/skills へのリンクではなく、dsh の
      # skill-filesystem 設定（--patch で渡す customSkillDirs）で指定する。
      # 既定 root（~/.dsh/skills, ~/.agents/skills, プロジェクト配下）は
      # includeDefaultRoots により従来どおり有効。
    };
}
