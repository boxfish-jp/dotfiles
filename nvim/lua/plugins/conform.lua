local opts = {
  default_format_opts = {
    timeout_ms = 3000,
    async = false,
    quiet = false,
    lsp_format = "fallback",
  },
  formatters_by_ft = {
    ["javascript"] = { "biome-check" },
    ["javascriptreact"] = { "biome-check" },
    ["typescript"] = { "biome-check" },
    ["typescriptreact"] = { "biome-check" },
    ["Markdown"] = { "textlint" },
    ["json"] = { "biome-check" },
    ["css"] = { "biome-check" },
    ["dart"] = { "dart_format" },
    ["python"] = {
      "ruff_fix",
      "ruff_format",
      "ruff_organize_imports",
    },
  },
  formatters = {
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
      }),
    },
  },
}

require("conform").setup(opts)

local map = vim.keymap.set

map({ "n", "x" }, "<leader>cf", function()
  require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Format" })

map({ "n", "x" }, "<leader>cF", function()
  require("conform").format({ formatters = { "injected" }, timeout_ms = 3000 })
end, { desc = "Format Injected Langs" })

vim.g.autoformat = true

map("n", "<leader>uf", function()
  vim.g.autoformat = not vim.g.autoformat
  if vim.g.autoformat then
    vim.notify("Auto format (global): enabled", vim.log.levels.INFO)
  else
    vim.notify("Auto format (global): disabled", vim.log.levels.WARN)
  end
end, { desc = "Toggle Auto Format (Global)" })

map("n", "<leader>uF", function()
  vim.b.autoformat = vim.b.autoformat == nil and false or (vim.b.autoformat and false or true)
  if vim.b.autoformat == false then
    vim.notify("Auto format (buffer): disabled", vim.log.levels.WARN)
  else
    vim.notify("Auto format (buffer): enabled", vim.log.levels.INFO)
  end
end, { desc = "Toggle Auto Format (Buffer)" })

vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("AutoFormat", { clear = true }),
  callback = function()
    if vim.g.autoformat == false then
      return
    end
    if vim.b.autoformat == false then
      return
    end
    require("conform").format({ async = false, lsp_format = "fallback" })
  end,
})
