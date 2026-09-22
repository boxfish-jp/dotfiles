{ self, ... }:
{
  flake.homeModules."laptop/stream" = _: {
    imports = [
      self.homeModules.containers
      self.homeModules.kanata
      self.homeModules.qpwgraph
      self.homeModules.vicinae
      self.homeModules.nvim
      self.homeModules.kde_plasma
      self.homeModules.fcitx5
      self.homeModules.alacritty
      self.homeModules.ghostty
      self.homeModules.zellij
      self.homeModules.git
      self.homeModules.bash
      self.homeModules.llm
      self.homeModules.btop
      self.homeModules.spotify
      self.homeModules.other_cli
      self.homeModules.other_gui
      self.homeModules.obs
      self.homeModules.streaming
    ];

    home.stateVersion = "26.11";

    programs.home-manager.enable = true;
  };
}
