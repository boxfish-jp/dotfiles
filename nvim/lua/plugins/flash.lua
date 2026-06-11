vim.keymap.set("n", "s", function()
  require("flash").jump()
end, { desc = "Flash" })
vim.keymap.set("x", "s", function()
  require("flash").jump()
end, { desc = "Flash" })
vim.keymap.set("o", "s", function()
  require("flash").jump()
end, { desc = "Flash" })

-- Flash Treesitter
vim.keymap.set("n", "S", function()
  require("flash").treesitter()
end, { desc = "Flash Treesitter" })
vim.keymap.set("x", "S", function()
  require("flash").treesitter()
end, { desc = "Flash Treesitter" })
vim.keymap.set("o", "S", function()
  require("flash").treesitter()
end, { desc = "Flash Treesitter" })

-- Remote Flash
vim.keymap.set("o", "r", function()
  require("flash").remote()
end, { desc = "Remote Flash" })

-- Treesitter Search
vim.keymap.set("o", "R", function()
  require("flash").treesitter_search()
end, { desc = "Treesitter Search" })
vim.keymap.set("x", "R", function()
  require("flash").treesitter_search()
end, { desc = "Treesitter Search" })

-- Toggle Flash Search
vim.keymap.set("c", "<C-s>", function()
  require("flash").toggle()
end, { desc = "Toggle Flash Search" })
-- flash.nvim --
