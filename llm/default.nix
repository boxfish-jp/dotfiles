{
  self,
  inputs,
  lib,
  ...
}:
let
  # opencode 設定ツリー（node_modules と test/ は含めない）
  opencodeConfigTree = lib.fileset.toSource {
    root = ./opencode;
    fileset = lib.fileset.unions [
      ./opencode/AGENTS.md
      ./opencode/lib
      ./opencode/opencode.jsonc
      ./opencode/plugins
      ./opencode/skills
      ./opencode/themes
      ./opencode/tui.json
    ];
  };
in
{
  perSystem =
    { pkgs, system, ... }:
    {
      # nix run .#opencode で設定込みの実行ができる。
      # opencode は起動時に設定ディレクトリへ .gitignore / package.json /
      # node_modules を書き込むため、store 直下を OPENCODE_CONFIG_DIR に
      # できず、毎回 writable なステージ先へ設定を同期してから起動する。
      packages.opencode =
        let
          base = inputs.llm-agents.packages.${system}.opencode;
        in
        pkgs.writeShellScriptBin "opencode" ''
          set -eu
          stage="''${XDG_STATE_HOME:-$HOME/.local/state}/opencode-packaged"
          mkdir -p "$stage"
          chmod -R u+w "$stage" 2>/dev/null || true
          cp -R ${opencodeConfigTree}/. "$stage/"
          chmod -R u+w "$stage"
          export OPENCODE_CONFIG_DIR="$stage"
          exec ${lib.getExe base} "$@"
        '';
    };

  flake.homeModules.llm =
    {
      config,
      pkgs,
      self,
      ...
    }:
    {
      imports = [ self.homeModules.kimaki ];

      llm.kimaki.enable = config.home.username == "sandbox";

      home.packages = with pkgs; [
        llm-agents.opencode
      ];

      home.sessionVariables = {
        OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = "true";
      };

      xdg.configFile."opencode".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/llm/opencode";
    }

  ;
}
