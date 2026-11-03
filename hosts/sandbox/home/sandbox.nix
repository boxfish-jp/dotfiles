{ self, ... }:
{
  flake.homeModules."sandbox/sandbox" = _: {
    imports = [
      self.homeModules.containers
      self.homeModules.browser-chan
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

    programs.home-manager.enable = true;
  };
}
