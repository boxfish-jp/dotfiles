-- neo-treeの読み込み
local neo_tree = require("neo-tree")
local command = require("neo-tree.command")

-- セットアップ時のオプション
local opts = {
  sources = { "filesystem", "buffers", "git_status" },
  open_files_do_not_replace_types = { "terminal", "Trouble", "trouble", "qf", "Outline" },
  filesystem = {
    bind_to_cwd = false,
    follow_current_file = { enabled = true },
    use_libuv_file_watcher = true,
  },
  window = {
    mappings = {
      ["l"] = "open",
      ["h"] = "close_node",
      ["<space>"] = "none",
      ["Y"] = {
        function(state)
          local node = state.tree:get_node()
          local path = node:get_id()
          vim.fn.setreg("+", path, "c")
        end,
        desc = "Copy Path to Clipboard",
      },
      ["O"] = {
        function(state)
          -- lazy.util.open の代わりにvim.ui.openを使用
          vim.ui.open(state.tree:get_node().path)
        end,
        desc = "Open with System Application",
      },
      ["P"] = { "toggle_preview", config = { use_float = false } },
    },
  },
  default_component_configs = {
    indent = {
      with_expanders = true,
      expander_collapsed = "",
      expander_expanded = "",
      expander_highlight = "NeoTreeExpander",
    },
    git_status = {
      symbols = {
        unstaged = "󰄱",
        staged = "󰱒",
      },
    },
  },
}

-- ファイル移動/リネーム時の処理
local function on_move(data)
  -- Snacksが利用可能ならSnacks.rename.on_rename_fileを使用
  local ok, snacks = pcall(require, "snacks")
  if ok and snacks.rename then
    snacks.rename.on_rename_file(data.source, data.destination)
  end
end

-- イベントハンドラの設定
local events = require("neo-tree.events")
opts.event_handlers = {
  { event = events.FILE_MOVED, handler = on_move },
  { event = events.FILE_RENAMED, handler = on_move },
}

-- neo-treeのセットアップ
neo_tree.setup(opts)

-- lazylogit終了時にgit_statusを更新
vim.api.nvim_create_autocmd("TermClose", {
  pattern = "*lazygit",
  callback = function()
    if package.loaded["neo-tree.sources.git_status"] then
      require("neo-tree.sources.git_status").refresh()
    end
  end,
})

-- 起動時のディレクトリ対応（initの処理）
vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("Neotree_start_directory", { clear = true }),
  desc = "Start Neo-tree with directory",
  once = true,
  callback = function()
    if package.loaded["neo-tree"] then
      return
    end
    local stats = vim.uv.fs_stat(vim.fn.argv(0))
    if stats and stats.type == "directory" then
      require("neo-tree")
    end
  end,
})

-- キーマッピング
vim.keymap.set("n", "<leader>fe", function()
  -- LazyVim.root() の代わりにvim.fn.getcwd()や手動ルート検出
  local root = vim.fn.getcwd() -- または適切なルート検出ロジック
  command.execute({ toggle = true, dir = root })
end, { desc = "Explorer NeoTree (Root Dir)" })

vim.keymap.set("n", "<leader>fE", function()
  command.execute({ toggle = true, dir = vim.uv.cwd() })
end, { desc = "Explorer NeoTree (cwd)" })

-- リマップ
vim.keymap.set("n", "<leader>e", "<leader>fe", { desc = "Explorer NeoTree (Root Dir)", remap = true })
vim.keymap.set("n", "<leader>E", "<leader>fE", { desc = "Explorer NeoTree (cwd)", remap = true })

vim.keymap.set("n", "<leader>ge", function()
  command.execute({ source = "git_status", toggle = true })
end, { desc = "Git Explorer" })

vim.keymap.set("n", "<leader>be", function()
  command.execute({ source = "buffers", toggle = true })
end, { desc = "Buffer Explorer" })

-- 無効化時の処理（deactivateの代替として、必要に応じて呼び出す関数）
vim.api.nvim_create_user_command("NeotreeDeactivate", function()
  vim.cmd([[Neotree close]])
end, {})
