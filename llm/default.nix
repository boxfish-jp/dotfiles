{
  config,
  pkgs,
  lib,
  username,
  ...
}:
{
  imports = lib.optionals (username == "sandbox") [ ./kimaki ];

  home.packages = with pkgs; [
    llm-agents.opencode
  ];

  home.sessionVariables = {
    OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = "true";
  };

  xdg.configFile."opencode".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/llm/opencode";
}
