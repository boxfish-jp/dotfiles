{ self, ... }:
{
  flake.homeModules.llm =
    {
      config,
      pkgs,
      self,
      ...
    }:
    {
      imports = [ self.homeModules.kimaki ];

      llm.kimaki.enable = config.home.username == "sandbox";

      home.packages = with pkgs; [
        llm-agents.opencode
      ];

      home.sessionVariables = {
        OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = "true";
      };

      xdg.configFile."opencode".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/llm/opencode";
    }

  ;
}
