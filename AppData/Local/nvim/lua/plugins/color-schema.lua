return {
  --[[
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = true,
      color_overrides = {
        latte = { -- copied from gruvbox theme
          rosewater = "#c14a4a",
          flamingo = "#c14a4a",
          pink = "#945e80",
          mauve = "#945e80",
          red = "#c14a4a",
          maroon = "#c14a4a",
          peach = "#c35e0a",
          yellow = "#a96b2c",
          green = "#6c782e",
          teal = "#4c7a5d",
          sky = "#4c7a5d",
          sapphire = "#4c7a5d",
          blue = "#45707a",
          lavender = "#45707a",
          text = "#654735",
          subtext1 = "#7b5d44",
          subtext0 = "#8f6f56",
          overlay2 = "#a28368",
          overlay1 = "#b6977a",
          overlay0 = "#c9aa8c",
          surface2 = "#A79C86",
          surface1 = "#C9C19F",
          surface0 = "#DFD6B1",
          base = "#fbf1c7",
          mantle = "#F3EAC1",
          crust = "#E7DEB7",
        },
        mocha = { -- custom
          rosewater = "#ffc6be",
          flamingo = "#fb4934",
          pink = "#ff75a0",
          mauve = "#d3869b",
          red = "#ff5d62",    -- "#f2594b",
          maroon = "#fe8019",
          peach = "#e6c384",  -- "#FFAD7D",
          yellow = "#d79921", -- "#DEB22C",
          green = "#a9b665",
          teal = "#8ec07c",
          sky = "#a3d4d5",      -- #7daea3",
          sapphire = "#689d6a",
          blue = "#7fb4ca",     -- "#6d8dad",
          lavender = "#b16286",
          text = "#fbf1c7",     -- #D4BE98  #C6D0F5
          subtext1 = "#d5c4a1", -- #BDAE8B  #B3BCDF
          subtext0 = "#a89984", -- #A69372  #A1A8C9
          overlay2 = "#8C7A58", -- #8E95B3
          overlay1 = "#735F3F", -- #7B819D
          overlay0 = "#806234", -- #696D86
          surface2 = "#665c54", -- #6E7477  #4B4F51  #565970
          surface1 = "#735F30", -- #2A2D2E           #43465A
          surface0 = "#323020", -- #232728           #313244
          base = "#282828",     -- #1D2021           #1E1E2E
          mantle = "#1d2021",   -- #191C1D           #181825
          crust = "#1b1b1b",    --                   #11111B
        },
      },
      integrations = {
        aerial = true,
        alpha = true,
        cmp = true,
        dashboard = true,
        flash = true,
        fzf = true,
        grug_far = true,
        gitsigns = true,
        headlines = true,
        illuminate = true,
        indent_blankline = { enabled = true },
        leap = true,
        lsp_trouble = true,
        mason = true,
        markdown = true,
        mini = true,
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { "undercurl" },
            hints = { "undercurl" },
            warnings = { "undercurl" },
            information = { "undercurl" },
          },
        },
        navic = { enabled = true, custom_bg = "lualine" },
        neotest = true,
        neotree = true,
        noice = true,
        notify = true,
        semantic_tokens = true,
        snacks = true,
        telescope = true,
        treesitter = true,
        treesitter_context = true,
        which_key = true,
      },
    },
    specs = {
      {
        "akinsho/bufferline.nvim",
        optional = true,
        opts = function(_, opts)
          if (vim.g.colors_name or ""):find("catppuccin") then
            opts.highlights = require("catppuccin.groups.integrations.bufferline").get()
          end
        end,
      },
    },
  },
]] --
  {
    "scottmckendry/cyberdream.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      transparent = true,
      highlights = {
        -- Highlight groups to override, adding new groups is also possible
        -- See `:h highlight-groups` for a list of highlight groups or run `:hi` to see all groups and their current values

        -- Example:
        LineNrAbove = { fg = "grey", bg = "NONE" },
        LineNrBelow = { fg = "grey", bg = "NONE" },
        CursorLineNr = { fg = "orange", bg = "NONE", italic = true }
        -- More examples can be found in `lua/cyberdream/extensions/*.lua`
      },
    }
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "cyberdream",
    },
  }
}
