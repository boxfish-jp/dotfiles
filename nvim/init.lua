vim.g.startup_time = vim.loop.now()
vim.loader.enable()
do
  require("options")
  require("globals")
  require("mappings")
  require("plugins.init")
  require("lsp")
  vim.schedule(function()
    vim.o.clipboard = "unnamedplus"
  end)
end

if vim.env.NVIM_TERM == "1" and vim.fn.argc() == 0 then
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      vim.defer_fn(function()
        local cmd = vim.env.NVIM_TERM_CMD
        Snacks.terminal(cmd, {
          count = 1,
          env = { SNACKS_TERM = "bottom" },
          win = { position = "bottom", wo = { winbar = "" } },
        })
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype == "ministarter" then
            vim.api.nvim_win_close(win, true)
          end
        end
        if not cmd then
          vim.cmd.startinsert()
        end
      end, 50)
    end,
  })
end
