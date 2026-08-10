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
    # 上流のwrapperがPATHにnodejsと$out/binをprefixするせいで、
    # vicinaeから起動したアプリ(ghostty等)にnodejsが漏れるため除去する。
    # extension-managerはnodeをPATHから探すので、VICINAE_NODE_BINで明示指定する。
    package = inputs.vicinae.packages.${system}.default.overrideAttrs (prev: {
      qtWrapperArgs = lib.filter (a: !lib.hasPrefix "--prefix PATH" a) prev.qtWrapperArgs ++ [
        "--set VICINAE_NODE_BIN ${pkgs.nodejs}/bin/node"
      ];
    });
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
