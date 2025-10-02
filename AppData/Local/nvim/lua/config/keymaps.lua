-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
function Close_diff_buffers() end

local function compare_to_clipboard()
  local ftype = vim.api.nvim_eval("&filetype")
  vim.cmd(string.format(
    [[
    vsplit
    wincmd l
    enew
    setlocal buftype=nofile | set filetype=%s
    normal! P
    diffthis
    wincmd h | diffthis
  ]],
    ftype
  ))
end

vim.keymap.set("n", "<leader>bc", compare_to_clipboard, { desc = "Compare to clipboard" })
vim.keymap.set("x", "p", "P", { desc = "Replace selected text with clipboard content" })
