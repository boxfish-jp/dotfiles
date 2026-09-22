{
  self,
  inputs,
  lib,
  ...
}:
let
  # nvim 設定ツリー（init.lua と lua/ のみ）
  nvimConfigTree = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./init.lua
      ./lua
    ];
  };

  mkNvim =
    {
      pkgs,
      dynamic ? false,
    }:
    let
      vimdoc-ja = pkgs.vimUtils.buildVimPlugin {
        name = "vimdoc-ja";
        src = pkgs.fetchFromGitHub {
          owner = "vim-jp";
          repo = "vimdoc-ja";
          rev = "14c414edc2096aed90bc17d8bd51c42a9421ec6b";
          hash = "sha256-D6//4LSJs7ehdn+RYMwN7ynncweX0xyuvTrm12bD1oQ=";
        };
      };
    in
    pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped {
      withNodeJs = true;
      viAlias = true;
      vimAlias = true;
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
        mini-surround
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
            tree-sitter-dart
          ]
        ))
        nvim-treesitter-parsers.regex
        nvim-treesitter-parsers.cpp
      ];
      wrapRc = !dynamic;
      luaRcContent = lib.optionalString (!dynamic) ''
        vim.opt.rtp:prepend("${nvimConfigTree}")
        dofile("${nvimConfigTree}/init.lua")
      '';
    };
in
{
  perSystem =
    { pkgs, ... }:
    let
      nvim = mkNvim { inherit pkgs; };
    in
    {
      packages = {
        nvim = nvim;
        nvim-dynamic = mkNvim {
          inherit pkgs;
          dynamic = true;
        };
      };
    };

  flake.homeModules.nvim =
    { config, pkgs, ... }:
    {
      home.packages = [ self.packages.${pkgs.system}.nvim ];
      home.sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };
      xdg.configFile."nvim".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dotfiles/nvim";
    };
}
