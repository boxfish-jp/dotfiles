{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.packages = with pkgs; [
    llm-agents.opencode
  ];

  xdg.configFile."opencode/opencode.jsonc".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/opencode/opencode.jsonc";
}
