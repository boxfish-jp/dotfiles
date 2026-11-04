{ self, ... }:
{
  flake.homeModules."sandbox/sandbox" = _: {
    imports = [
      self.homeModules.containers
      self.homeModules.browser-chan
      self.homeModules.anime-log-mcp
      self.homeModules.nvim
      self.homeModules.zellij
      self.homeModules.git
      self.homeModules.bash
      self.homeModules.llm
      self.homeModules.agents-anywhere-connector
    ];

    home.stateVersion = "26.11";

    services.agents-anywhere-connector.enable = true;

    services.browser-chan.enable = true;

    # token は ~/.config/anime-log-mcp/.env に 0600 で置く。無いとサーバーは
    # 起動直後に終了し、5 秒ごとに再起動を繰り返す。
    services.anime-log-mcp.enable = true;

    programs.home-manager.enable = true;
  };
}
