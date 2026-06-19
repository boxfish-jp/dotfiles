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
}
