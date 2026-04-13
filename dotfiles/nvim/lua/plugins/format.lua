return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = {
        ["javascript"] = { "biome-check" },
        ["javascriptreact"] = { "biome-check" },
        ["typescript"] = { "biome-check" },
        ["typescriptreact"] = { "biome-check" },
        ["Markdown"] = { "textlint" },
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
      opts.formatters = {
        textlint = {
          meta = {
            url = "https://github.com/textlint/textlint",
            description = "The pluggable natural language linter for text and markdown.",
          },
          command = require("conform.util").from_node_modules("textlint"),
          stdin = true,
          args = {
            "--fix",
            "--stdin",
            "--stdin-filename",
            "$FILENAME",
            "--format",
            "fixed-result",
            "--dry-run",
          },
          cwd = require("conform.util").root_file({
            "package.json",
          })
        }
      }
      return opts
    end,
  },
}
