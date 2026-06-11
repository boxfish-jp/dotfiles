local grug = require("grug-far")

-- セットアップ
grug.setup({
  headerMaxWidth = 80,
})

-- キーマッピング
vim.keymap.set({ "n", "x" }, "<leader>sr", function()
  local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
  grug.open({
    transient = true,
    prefills = {
      filesFilter = ext and ext ~= "" and "*." .. ext or nil,
    },
  })
end, { desc = "Search and Replace" })

-- コマンドの作成（cmd = { "GrugFar", "GrugFarWithin" } の代替）
vim.api.nvim_create_user_command("GrugFar", function()
  grug.open({ transient = true })
end, {})

vim.api.nvim_create_user_command("GrugFarWithin", function()
  local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
  grug.open({
    transient = true,
    prefills = {
      filesFilter = ext and ext ~= "" and "*." .. ext or nil,
    },
  })
end, {})
