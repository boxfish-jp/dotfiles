{config, pkgs, ... }: {
  programs.vicinae = {
    enable = true;
    systemd = {
      enable = true;
      autoStart = true;
    };
  };
  xdg.dataFile = {
    "vicinae/scripts".source =
      ./scripts;
  };
}
