{
  config,
  pkgs,
  lib,
  username,
  ...
}:
{
  home.packages =
    with pkgs;
    lib.optionals (username != "server") [
      (pkgs.callPackage ./kimaki { })
    ]
    ++ [
      llm-agents.opencode
    ];

  xdg.configFile."opencode".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/llm/opencode";
}
