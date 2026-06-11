local noice = require("noice")

-- Lazyのメッセージをクリア（Lazyがインストール中のメッセージ対策）
if vim.o.filetype == "lazy" then
  vim.cmd([[messages clear]])
end

-- セットアップ
noice.setup({
  lsp = {
    override = {
      ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
      ["vim.lsp.util.stylize_markdown"] = true,
      ["cmp.entry.get_documentation"] = true,
    },
  },
  routes = {
    {
      filter = {
        event = "msg_show",
        any = {
          { find = "%d+L, %d+B" },
          { find = "; after #%d+" },
          { find = "; before #%d+" },
        },
      },
      view = "mini",
    },
  },
  presets = {
    bottom_search = true,
    command_palette = true,
    long_message_to_split = true,
  },
})

-- キーマッピング
-- Noice用のプレフィックスキー
vim.keymap.set("n", "<leader>sn", "", { desc = "+noice" })

-- コマンドラインモードでEnterを押しながらリダイレクト
vim.keymap.set("c", "<S-Enter>", function()
  noice.redirect(vim.fn.getcmdline())
end, { desc = "Redirect Cmdline" })

-- 最後のメッセージを表示
vim.keymap.set("n", "<leader>snl", function()
  noice.cmd("last")
end, { desc = "Noice Last Message" })

-- メッセージ履歴を表示
vim.keymap.set("n", "<leader>snh", function()
  noice.cmd("history")
end, { desc = "Noice History" })

-- すべてのメッセージを表示
vim.keymap.set("n", "<leader>sna", function()
  noice.cmd("all")
end, { desc = "Noice All" })

-- すべてのメッセージを消去
vim.keymap.set("n", "<leader>snd", function()
  noice.cmd("dismiss")
end, { desc = "Dismiss All" })

-- ピッカーを開く
vim.keymap.set("n", "<leader>snt", function()
  noice.cmd("pick")
end, { desc = "Noice Picker (Telescope/FzfLua)" })

-- LSPホバーやシグネチャヘルプでのスクロール
vim.keymap.set({ "i", "n", "s" }, "<c-f>", function()
  if not require("noice.lsp").scroll(4) then
    return "<c-f>"
  end
end, { silent = true, expr = true, desc = "Scroll Forward" })

vim.keymap.set({ "i", "n", "s" }, "<c-b>", function()
  if not require("noice.lsp").scroll(-4) then
    return "<c-b>"
  end
end, { silent = true, expr = true, desc = "Scroll Backward" })
