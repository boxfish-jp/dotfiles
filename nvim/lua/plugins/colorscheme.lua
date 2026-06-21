require("cyberdream").setup({
  transparent = true,
  highlights = {
    LineNrAbove = { fg = "grey", bg = "NONE" },
    LineNrBelow = { fg = "grey", bg = "NONE" },
    CursorLineNr = { fg = "orange", bg = "NONE", italic = true },
  },
})

vim.cmd("colorscheme cyberdream")
