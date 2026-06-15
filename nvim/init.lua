vim.g.startup_time = vim.loop.now()
vim.loader.enable()
do
  require("options")
  require("globals")
  require("mappings")
  require("plugins.init")
  vim.schedule(function()
    vim.o.clipboard = "unnamedplus"
  end)
end
