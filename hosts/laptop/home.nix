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
    ../../ghostty
    ../../zellij
    ../../git
    ../../bash
    ../../direnv
    ../../llm
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

  programs.home-manager.enable = true;
}
