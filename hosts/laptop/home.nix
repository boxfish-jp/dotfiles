{
  username,
  ...
}:
{
  imports = [
    ../../containers
    ../../kanata
    ../../qpwgraph
    ../../vicinae
    ../../nvim
    ../../kde_plasma
    ../../fcitx5
    ../../alacritty
    ../../zellij
    ../../git
    ../../bash
    ../../llm
    ../../btop
    ../../other_cli
    ../../other_gui
  ];
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
}
