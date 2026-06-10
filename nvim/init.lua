local function gh(repo) return 'https://github.com/' .. repo end
do
  require("options")
  require("mappings")
  vim.loader.enable()
  vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)
  vim.pack.add { gh 'vim-jp/vimdoc-ja' }
end
