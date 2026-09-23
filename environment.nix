{ self, ... }:
{
  # 設定済み ghostty にツール一式を注入したターミナル環境。
  flake.wrappers.terminal =
    { pkgs, ... }:
    {
      imports = [ self.wrapperModules.ghostty ];

      aliases = [ "terminal" ];

      # 設定込みのツール一式を wrapper の実行時 PATH に注入し、
      # nix run github:<repo>#terminal だけで完結させる。
      runtimePkgs = [
        self.packages.${pkgs.system}.bash
        self.packages.${pkgs.system}.nvim
        self.packages.${pkgs.system}.opencode
        self.packages.${pkgs.system}.zellij
      ];

      # zellij のペインシェルは $SHELL 参照なので repo bash にピン留めする。
      env.SHELL = "${self.packages.${pkgs.system}.bash}/bin/bash";

      settings.command = "zellij";
    };
}
