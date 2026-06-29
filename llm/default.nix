{
  config,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    llm-agents.opencode
  ];

  xdg.configFile."opencode".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/llm/opencode";
}
