{
  config,
  pkgs,
  lib,
  ...
}:
let
  grammars = with pkgs.tree-sitter-grammars; [
    tree-sitter-lua
    tree-sitter-python
    tree-sitter-typescript
    tree-sitter-nix
  ];
  mkParserEntry = pkg: {
    name = "nvim/site/parser/${lib.removePrefix "tree-sitter-" pkg.pname}.so";
    value = {
      source = "${pkg}/parser";
    };
  };

  mkQueriesEntry = pkg: {
    name = "nvim/site/queries/${lib.removePrefix "tree-sitter-" pkg.pname}";
    value = {
      source = "${pkg}/queries";
    };
  };

  allEntries = map mkParserEntry grammars ++ map mkQueriesEntry grammars;

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
    ];
  };
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/nvim";

  xdg.dataFile = lib.listToAttrs allEntries;
}
