return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = {
        ["javascript"] = { "biome-check" },
        ["javascriptreact"] = { "biome-check" },
        ["typescript"] = { "biome-check" },
        ["typescriptreact"] = { "biome-check" },
        ["json"] = { "biome-check" },
        ["css"] = { "biome-check" },
        ["python"] = {
          -- To fix auto-fixable lint errors.
          "ruff_fix",
          -- To run the Ruff formatter.
          "ruff_format",
          -- To organize the imports.
          "ruff_organize_imports",
        },
      }
      return opts
    end,
  },
}
