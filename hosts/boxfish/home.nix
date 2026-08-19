{
  username,
  ...
}:
{
  imports = [
    ../../containers
    ../../voicevox_container
    ../../kanata
    ../../flatpak
    ../../qpwgraph
    ../../obs
    ../../streaming
    ../../vicinae
    ../../nvim
    ../../kde_plasma
    ../../fcitx5
    ../../alacritty
    ../../ghostty
    ../../pipewire
    ../../zellij
    ../../git
    ../../video_editor
    ../../bash
    ../../llm
    ../../paint
    ../../btop
    ../../spotify
    ../../other_cli
    ../../other_gui
  ];
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "26.11";
  };

  services.voicevox_container = {
    enable = true;
    gpu = "nvidia";
  };

  programs.home-manager.enable = true;
}
