{ self, ... }:
{
  flake.homeModules."game/game" = _: {
    imports = [
      self.homeModules.containers
      self.homeModules.nvim
      self.homeModules.zellij
      self.homeModules.git
      self.homeModules.bash
    ];

    home.stateVersion = "26.11";

    programs.home-manager.enable = true;
  };
}
