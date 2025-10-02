-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here
vim.o.wrap = true

vim.api.nvim_create_user_command('Code', function()
  vim.system({ "code", "." })
end, {})
vim.api.nvim_create_user_command('Explorer', function()
  vim.system({ "explorer", "." })
end, {})
