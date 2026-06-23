-- ステータスラインの初期設定
vim.g.lualine_laststatus = vim.o.laststatus

if vim.fn.argc(-1) > 0 then
  -- ファイルを開いている場合は空のステータスラインを設定
  vim.o.statusline = " "
else
  -- スターターページではステータスラインを非表示
  vim.o.laststatus = 0
end

-- lualineのrequire最適化
local lualine_require = require("lualine_require")
lualine_require.require = require

-- アイコンの設定（LazyVimのアイコンがない場合はデフォルト値を使用）
local icons = {
  diagnostics = {
    Error = " ",
    Warn = " ",
    Info = " ",
    Hint = " ",
  },
  git = {
    added = " ",
    modified = " ",
    removed = " ",
  },
}

-- Snacksが利用可能な場合はSnacksのカラー関数を使用
local function get_snacks_color(group)
  local ok, snacks = pcall(require, "snacks")
  if ok and snacks.util and snacks.util.color then
    return { fg = snacks.util.color(group) }
  end
  return {}
end

-- ステータスラインを元に戻す
vim.o.laststatus = vim.g.lualine_laststatus

-- オプションの設定
local opts = {
  options = {
    theme = "auto",
    globalstatus = vim.o.laststatus == 3,
    disabled_filetypes = { statusline = { "dashboard", "alpha", "ministarter", "snacks_dashboard" } },
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch" },
    lualine_c = {
      -- ルートディレクトリ表示（LazyVim.lualine.root_dir()の代替）
      {
        function()
          local root = vim.fn.getcwd()
          local root_name = vim.fn.fnamemodify(root, ":t")
          return "󰉋 " .. root_name
        end,
        cond = function()
          return vim.fn.getcwd() ~= vim.env.HOME
        end,
        color = { fg = "#FF9E64" },
      },
      {
        "diagnostics",
        symbols = {
          error = icons.diagnostics.Error,
          warn = icons.diagnostics.Warn,
          info = icons.diagnostics.Info,
          hint = icons.diagnostics.Hint,
        },
      },
      { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
      -- ファイルパス表示
      {
        function()
          local filename = vim.fn.expand("%:.")
          if filename == "" then
            return "[No Name]"
          end
          local modified = vim.bo.modified and " +" or ""
          return filename .. modified
        end,
      },
    },
    lualine_x = {
      -- Noiceコマンドステータス
      {
        function()
          return require("noice").api.status.command.get()
        end,
        cond = function()
          return package.loaded["noice"] and require("noice").api.status.command.has()
        end,
        color = function()
          return get_snacks_color("Statement")
        end,
      },
      -- Noiceモードステータス
      {
        function()
          return require("noice").api.status.mode.get()
        end,
        cond = function()
          return package.loaded["noice"] and require("noice").api.status.mode.has()
        end,
        color = function()
          return get_snacks_color("Constant")
        end,
      },
      -- DAPステータス
      {
        function()
          return "  " .. require("dap").status()
        end,
        cond = function()
          return package.loaded["dap"] and require("dap").status() ~= ""
        end,
        color = function()
          return get_snacks_color("Debug")
        end,
      },
      -- Git差分
      {
        "diff",
        symbols = {
          added = icons.git.added,
          modified = icons.git.modified,
          removed = icons.git.removed,
        },
        source = function()
          local gitsigns = vim.b.gitsigns_status_dict
          if gitsigns then
            return {
              added = gitsigns.added,
              modified = gitsigns.changed,
              removed = gitsigns.removed,
            }
          end
        end,
      },
    },
    lualine_y = {
      { "progress", separator = " ", padding = { left = 1, right = 0 } },
      { "location", padding = { left = 0, right = 1 } },
    },
    lualine_z = {
      function()
        return " " .. os.date("%R")
      end,
    },
  },
  extensions = { "neo-tree", "lazy", "fzf" },
}

-- Trouble.nvimの設定
if vim.g.trouble_lualine then
  local ok, trouble = pcall(require, "trouble")
  if ok then
    local symbols = trouble.statusline({
      mode = "symbols",
      groups = {},
      title = false,
      filter = { range = true },
      format = "{kind_icon}{symbol.name:Normal}",
      hl_group = "lualine_c_normal",
    })
    table.insert(opts.sections.lualine_c, {
      symbols and symbols.get,
      cond = function()
        return vim.b.trouble_lualine ~= false and symbols.has()
      end,
    })
  end
end

-- lualineのセットアップ
require("lualine").setup(opts)
