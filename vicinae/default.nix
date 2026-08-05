{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  braveSearch = inputs.vicinae.lib.${system}.mkVicinaeExtension {
    pname = "vicinae-extension-brave-search";
    version = "0";
    src = lib.cleanSource ./brave-search;
    npmFlags = [ "--legacy-peer-deps" ];
  };
in
{
  programs.vicinae = {
    enable = true;
    systemd = {
      enable = true;
      autoStart = true;
    };
    extensions = with inputs.vicinae-extensions.packages.${system}; [
      nix
      braveSearch
    ];
  };
  xdg.dataFile = {
    "vicinae/scripts".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/vicinae/scripts";
  };
}
