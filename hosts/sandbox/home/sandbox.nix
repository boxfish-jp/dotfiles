{ self, ... }:
{
  flake.homeModules."sandbox/sandbox" = _: {
    imports = [
      self.homeModules.containers
      self.homeModules.nvim
      self.homeModules.zellij
      self.homeModules.git
      self.homeModules.bash
      self.homeModules.llm
      self.homeModules.agents-anywhere-connector
    ];

    home.stateVersion = "26.11";

    services.agents-anywhere-connector.enable = true;

    programs.home-manager.enable = true;
  };
}
