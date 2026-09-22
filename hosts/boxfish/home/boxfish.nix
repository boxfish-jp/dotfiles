{ self, ... }:
{
  flake.homeModules."boxfish/boxfish" = _: {
    imports = [
      self.homeModules.containers
      self.homeModules.voicevox_container
      self.homeModules.kanata
      self.homeModules.flatpak
      self.homeModules.qpwgraph
      self.homeModules.obs
      self.homeModules.streaming
      self.homeModules.vicinae
      self.homeModules.nvim
      self.homeModules.kde_plasma
      self.homeModules.fcitx5
      self.homeModules.alacritty
      self.homeModules.ghostty
      self.homeModules.pipewire
      self.homeModules.zellij
      self.homeModules.git
      self.homeModules.video_editor
      self.homeModules.bash
      self.homeModules.llm
      self.homeModules.paint
      self.homeModules.btop
      self.homeModules.spotify
      self.homeModules.other_cli
      self.homeModules.other_gui
    ];

    home.stateVersion = "26.11";

    services.voicevox_container = {
      enable = true;
      gpu = "nvidia";
    };

    programs.home-manager.enable = true;
  };
}
