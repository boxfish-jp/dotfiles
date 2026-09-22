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
    ];

    home.stateVersion = "26.11";

    programs.home-manager.enable = true;
  };
}
