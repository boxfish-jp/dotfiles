vim.g.startup_time = vim.loop.now()
local function gh(repo)
  return "https://github.com/" .. repo
end
do
  require("options")
  require("globals")
  require("mappings")
  require("plugins.init")
  vim.loader.enable()
  vim.schedule(function()
    vim.o.clipboard = "unnamedplus"
  end)
end
