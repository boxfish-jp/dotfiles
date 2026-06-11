-- プラグインの読み込み
local yanky = require("yanky")

-- セットアップ
yanky.setup({
  system_clipboard = {
    sync_with_ring = not vim.env.SSH_CONNECTION,
  },
  highlight = { timer = 150 },
})

-- キーマッピングの設定
local function open_yank_history()
  local ok, snacks = pcall(require, "snacks")
  if ok then
    snacks.picker.yanky()
  else
    vim.cmd([[YankyRingHistory]])
  end
end

vim.keymap.set({ "n", "x" }, "<leader>p", open_yank_history, { desc = "Open Yank History" })

-- Yank/Put mappings
vim.keymap.set({ "n", "x" }, "y", "<Plug>(YankyYank)", { desc = "Yank Text" })
vim.keymap.set({ "n", "x" }, "p", "<Plug>(YankyPutAfter)", { desc = "Put Text After Cursor" })
vim.keymap.set({ "n", "x" }, "P", "<Plug>(YankyPutBefore)", { desc = "Put Text Before Cursor" })
vim.keymap.set({ "n", "x" }, "gp", "<Plug>(YankyGPutAfter)", { desc = "Put Text After Selection" })
vim.keymap.set({ "n", "x" }, "gP", "<Plug>(YankyGPutBefore)", { desc = "Put Text Before Selection" })

-- Cycle through yank history
vim.keymap.set("n", "[y", "<Plug>(YankyCycleForward)", { desc = "Cycle Forward Through Yank History" })
vim.keymap.set("n", "]y", "<Plug>(YankyCycleBackward)", { desc = "Cycle Backward Through Yank History" })

-- Indent-aware put
vim.keymap.set("n", "]p", "<Plug>(YankyPutIndentAfterLinewise)", { desc = "Put Indented After Cursor (Linewise)" })
vim.keymap.set("n", "[p", "<Plug>(YankyPutIndentBeforeLinewise)", { desc = "Put Indented Before Cursor (Linewise)" })
vim.keymap.set("n", "]P", "<Plug>(YankyPutIndentAfterLinewise)", { desc = "Put Indented After Cursor (Linewise)" })
vim.keymap.set("n", "[P", "<Plug>(YankyPutIndentBeforeLinewise)", { desc = "Put Indented Before Cursor (Linewise)" })
vim.keymap.set("n", ">p", "<Plug>(YankyPutIndentAfterShiftRight)", { desc = "Put and Indent Right" })
vim.keymap.set("n", "<p", "<Plug>(YankyPutIndentAfterShiftLeft)", { desc = "Put and Indent Left" })
vim.keymap.set("n", ">P", "<Plug>(YankyPutIndentBeforeShiftRight)", { desc = "Put Before and Indent Right" })
vim.keymap.set("n", "<P", "<Plug>(YankyPutIndentBeforeShiftLeft)", { desc = "Put Before and Indent Left" })

-- Filter put
vim.keymap.set("n", "=p", "<Plug>(YankyPutAfterFilter)", { desc = "Put After Applying a Filter" })
vim.keymap.set("n", "=P", "<Plug>(YankyPutBeforeFilter)", { desc = "Put Before Applying a Filter" })
