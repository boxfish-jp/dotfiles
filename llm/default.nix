{
  config,
  pkgs,
  lib,
  username,
  ...
}:
{
  imports = lib.optionals (username == "server" || username == "sandbox") [ ./kimaki ];

  home.packages = with pkgs; [
    llm-agents.opencode
  ];

  xdg.configFile."opencode".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/llm/opencode";
}
