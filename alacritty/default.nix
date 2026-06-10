{
  config,
  pkgs,
  lib,
  username,
  hostname,
  ...
}:{
  home.packages = [
    pkgs.alacritty
  ];

  xdg = {
    configFile."alacritty".source = ./.;

    dataFile = {
      "applications/alacritty.desktop".source = ./alacritty.desktop;
      "icons/alacritty.png".source = ./alacritty.png;
    };
  };
}
