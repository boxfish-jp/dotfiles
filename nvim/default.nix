{
  config,
  pkgs,
  lib,
  ...
}:
let
  vimdoc-ja = pkgs.vimUtils.buildVimPlugin {
    name = "vim-easygrep";
    src = pkgs.fetchFromGitHub {
      owner = "vim-jp";
      repo = "vimdoc-ja";
      rev = "7ad16f3f380b1eecbc0219bc6215283183681987";
      hash = "sha256-33NuoG01CFK1O0v7fjEvmUpqdPr5B9EWjaMc4lN3ShE=";
    };
  };
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    withNodeJs = true;
    viAlias = true;
    vimAlias = true;
    sideloadInitLua = true;
    plugins = with pkgs.vimPlugins; [
      nvim-treesitter
      cyberdream-nvim
      vimdoc-ja
      bufferline-nvim
      transparent-nvim
      which-key-nvim
      flash-nvim
      snacks-nvim
      mini-starter
      yanky-nvim
      neo-tree-nvim
      noice-nvim
      lualine-nvim
      grug-far-nvim
      gitsigns-nvim
      trouble-nvim
      todo-comments-nvim
      nvim-web-devicons
      mini-icons
      mini-pairs
      ts-comments-nvim
      mini-ai
      orgmode
      nvim-lspconfig
      conform-nvim
      blink-cmp
      CopilotChat-nvim
      (nvim-treesitter.withPlugins (
        p: with p; [
          tree-sitter-python
          tree-sitter-nix
          tree-sitter-javascript
          tree-sitter-typescript
          tree-sitter-tsx
          tree-sitter-json
          tree-sitter-css
          tree-sitter-html
        ]
      ))
      nvim-treesitter-parsers.regex
      nvim-treesitter-parsers.cpp
    ];
  };
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/nvim";
}
