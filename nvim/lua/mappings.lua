do
  -- [[ 基本的なキーマップ ]]
  -- 詳細は `:help vim.keymap.set()` を参照

  -- ノーマルモードで <Esc> を押したときに検索ハイライトをクリアする
  -- 詳細は `:help hlsearch` を参照
  -- vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
  
  -- 診断（Diagnostic）の設定とキーマップ
  -- 詳細は `:help vim.diagnostic.Opts` を参照
  vim.diagnostic.config {
    update_in_insert = false,
    severity_sort = true,
    float = { border = 'rounded', source = 'if_many' },
    underline = { severity = { min = vim.diagnostic.severity.WARN } },

    -- 好みに応じてこれらを切り替えることができます
    virtual_text = true, -- テキストが行末に表示されます
    virtual_lines = false, -- テキストが仮想行として行の下に表示されます

    -- フロートウィンドウを自動で開き、`[d` や `]d` でジャンプした際にエラーを簡単に読めるようにします
    jump = {
      on_jump = function(_, bufnr)
        vim.diagnostic.open_float {
          bufnr = bufnr,
          scope = 'cursor',
          focus = false,
        }
      end,
    },
  }
vim.keymap.set("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
vim.keymap.set("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next Buffer" })
vim.keymap.set("n", "[b", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
vim.keymap.set("n", "<leader>bd", function()
  Snacks.bufdelete()
end, { desc = "Delete Buffer" })
vim.keymap.set("n", "<leader>bo", function()
  Snacks.bufdelete.other()
end, { desc = "Delete Other Buffers" })
vim.keymap.set("n", "<leader>bi", function()
  Snacks.bufdelete.invisible()
end, { desc = "Delete Invisible Buffers" })
vim.keymap.set("n", "<leader>bD", "<cmd>:bd<cr>", { desc = "Delete Buffer and Window" })

  -- 分割ウィンドウ間の移動を簡単にするキーマップ。
  -- Ctrl + <hjkl> を使ってウィンドウ間を切り替えます
  --
  -- すべてのウィンドウコマンドの一覧については `:help wincmd` を参照してください
  vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = '左のウィンドウにフォーカスを移動' })
  vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = '右のウィンドウにフォーカスを移動' })
  vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = '下のウィンドウにフォーカスを移動' })
  vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = '上のウィンドウにフォーカスを移動' })

  vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = '診断 [Q]uickfix リストを開く' })
  -- テキストをヤンク（コピー）したときにハイライト表示する
  -- ノーマルモードで `yap` などを試してみてください
  -- 詳細は `:help vim.hl.on_yank()` を参照
  
  vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'ヤンク（コピー）時にテキストをハイライト',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function() vim.hl.on_yank() end,
  })

  -- flash.nvim --
  vim.keymap.set("n", "s", function() require("flash").jump() end, { desc = "Flash" })
vim.keymap.set("x", "s", function() require("flash").jump() end, { desc = "Flash" })
vim.keymap.set("o", "s", function() require("flash").jump() end, { desc = "Flash" })

-- Flash Treesitter
vim.keymap.set("n", "S", function() require("flash").treesitter() end, { desc = "Flash Treesitter" })
vim.keymap.set("x", "S", function() require("flash").treesitter() end, { desc = "Flash Treesitter" })
vim.keymap.set("o", "S", function() require("flash").treesitter() end, { desc = "Flash Treesitter" })

-- Remote Flash
vim.keymap.set("o", "r", function() require("flash").remote() end, { desc = "Remote Flash" })
 
-- Treesitter Search
vim.keymap.set("o", "R", function() require("flash").treesitter_search() end, { desc = "Treesitter Search" })
vim.keymap.set("x", "R", function() require("flash").treesitter_search() end, { desc = "Treesitter Search" })

-- Toggle Flash Search
vim.keymap.set("c", "<C-s>", function() require("flash").toggle() end, { desc = "Toggle Flash Search" })
  -- flash.nvim --
  
  -- snack.nvim --
  local Snacks = require("snacks")

-- Top Pickers & Explorer
vim.keymap.set("n", "<leader><space>", function() Snacks.picker.smart() end, { desc = "Smart Find Files" })
vim.keymap.set("n", "<leader>/", function() Snacks.picker.grep() end, { desc = "Grep" })
-- vim.keymap.set("n", "<leader>:", function() Snacks.picker.command_history() end, { desc = "Command History" })
vim.keymap.set("n", "<leader>n", function() Snacks.picker.notifications() end, { desc = "Notification History" })
vim.keymap.set("n", "<leader>e", function() Snacks.explorer() end, { desc = "File Explorer" })

-- find
vim.keymap.set("n", "<leader>fb", function() Snacks.picker.buffers() end, { desc = "Buffers" })
vim.keymap.set("n", "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, { desc = "Find Config File" })
vim.keymap.set("n", "<leader>ff", function() Snacks.picker.files() end, { desc = "Find Files" })
vim.keymap.set("n", "<leader>fg", function() Snacks.picker.git_files() end, { desc = "Find Git Files" })
vim.keymap.set("n", "<leader>fp", function() Snacks.picker.projects() end, { desc = "Projects" })
vim.keymap.set("n", "<leader>fr", function() Snacks.picker.recent() end, { desc = "Recent" })

-- git
vim.keymap.set("n", "<leader>gb", function() Snacks.picker.git_branches() end, { desc = "Git Branches" })
vim.keymap.set("n", "<leader>gl", function() Snacks.picker.git_log() end, { desc = "Git Log" })
vim.keymap.set("n", "<leader>gL", function() Snacks.picker.git_log_line() end, { desc = "Git Log Line" })
vim.keymap.set("n", "<leader>gs", function() Snacks.picker.git_status() end, { desc = "Git Status" })
vim.keymap.set("n", "<leader>gS", function() Snacks.picker.git_stash() end, { desc = "Git Stash" })
vim.keymap.set("n", "<leader>gd", function() Snacks.picker.git_diff() end, { desc = "Git Diff (Hunks)" })
vim.keymap.set("n", "<leader>gf", function() Snacks.picker.git_log_file() end, { desc = "Git Log File" })

-- gh
vim.keymap.set("n", "<leader>gi", function() Snacks.picker.gh_issue() end, { desc = "GitHub Issues (open)" })
vim.keymap.set("n", "<leader>gI", function() Snacks.picker.gh_issue({ state = "all" }) end, { desc = "GitHub Issues (all)" })
vim.keymap.set("n", "<leader>gp", function() Snacks.picker.gh_pr() end, { desc = "GitHub Pull Requests (open)" })
vim.keymap.set("n", "<leader>gP", function() Snacks.picker.gh_pr({ state = "all" }) end, { desc = "GitHub Pull Requests (all)" })

-- Grep
vim.keymap.set("n", "<leader>sb", function() Snacks.picker.lines() end, { desc = "Buffer Lines" })
vim.keymap.set("n", "<leader>sB", function() Snacks.picker.grep_buffers() end, { desc = "Grep Open Buffers" })
vim.keymap.set("n", "<leader>sg", function() Snacks.picker.grep() end, { desc = "Grep" })
vim.keymap.set({ "n", "x" }, "<leader>sw", function() Snacks.picker.grep_word() end, { desc = "Visual selection or word" })

-- search
vim.keymap.set("n", '<leader>s"', function() Snacks.picker.registers() end, { desc = "Registers" })
vim.keymap.set("n", '<leader>s/', function() Snacks.picker.search_history() end, { desc = "Search History" })
vim.keymap.set("n", "<leader>sa", function() Snacks.picker.autocmds() end, { desc = "Autocmds" })
vim.keymap.set("n", "<leader>sc", function() Snacks.picker.command_history() end, { desc = "Command History" })
vim.keymap.set("n", "<leader>sC", function() Snacks.picker.commands() end, { desc = "Commands" })
vim.keymap.set("n", "<leader>sd", function() Snacks.picker.diagnostics() end, { desc = "Diagnostics" })
vim.keymap.set("n", "<leader>sD", function() Snacks.picker.diagnostics_buffer() end, { desc = "Buffer Diagnostics" })
vim.keymap.set("n", "<leader>sh", function() Snacks.picker.help() end, { desc = "Help Pages" })
vim.keymap.set("n", "<leader>sH", function() Snacks.picker.highlights() end, { desc = "Highlights" })
vim.keymap.set("n", "<leader>si", function() Snacks.picker.icons() end, { desc = "Icons" })
vim.keymap.set("n", "<leader>sj", function() Snacks.picker.jumps() end, { desc = "Jumps" })
vim.keymap.set("n", "<leader>sk", function() Snacks.picker.keymaps() end, { desc = "Keymaps" })
vim.keymap.set("n", "<leader>sl", function() Snacks.picker.loclist() end, { desc = "Location List" })
vim.keymap.set("n", "<leader>sm", function() Snacks.picker.marks() end, { desc = "Marks" })
vim.keymap.set("n", "<leader>sM", function() Snacks.picker.man() end, { desc = "Man Pages" })
vim.keymap.set("n", "<leader>sq", function() Snacks.picker.qflist() end, { desc = "Quickfix List" })
vim.keymap.set("n", "<leader>sR", function() Snacks.picker.resume() end, { desc = "Resume" })
vim.keymap.set("n", "<leader>su", function() Snacks.picker.undo() end, { desc = "Undo History" })
vim.keymap.set("n", "<leader>uC", function() Snacks.picker.colorschemes() end, { desc = "Colorschemes" })

-- LSP
vim.keymap.set("n", "gd", function() Snacks.picker.lsp_definitions() end, { desc = "Goto Definition" })
vim.keymap.set("n", "gD", function() Snacks.picker.lsp_declarations() end, { desc = "Goto Declaration" })
vim.keymap.set("n", "gr", function() Snacks.picker.lsp_references() end, { nowait = true, desc = "References" })
vim.keymap.set("n", "gI", function() Snacks.picker.lsp_implementations() end, { desc = "Goto Implementation" })
vim.keymap.set("n", "gy", function() Snacks.picker.lsp_type_definitions() end, { desc = "Goto T[y]pe Definition" })
vim.keymap.set("n", "gai", function() Snacks.picker.lsp_incoming_calls() end, { desc = "C[a]lls Incoming" })
vim.keymap.set("n", "gao", function() Snacks.picker.lsp_outgoing_calls() end, { desc = "C[a]lls Outgoing" })
vim.keymap.set("n", "<leader>ss", function() Snacks.picker.lsp_symbols() end, { desc = "LSP Symbols" })
vim.keymap.set("n", "<leader>sS", function() Snacks.picker.lsp_workspace_symbols() end, { desc = "LSP Workspace Symbols" })

-- Other
vim.keymap.set("n", "<leader>z", function() Snacks.zen() end, { desc = "Toggle Zen Mode" })
vim.keymap.set("n", "<leader>Z", function() Snacks.zen.zoom() end, { desc = "Toggle Zoom" })
vim.keymap.set("n", "<leader>.", function() Snacks.scratch() end, { desc = "Toggle Scratch Buffer" })
vim.keymap.set("n", "<leader>S", function() Snacks.scratch.select() end, { desc = "Select Scratch Buffer" })
vim.keymap.set("n", "<leader>bd", function() Snacks.bufdelete() end, { desc = "Delete Buffer" })
vim.keymap.set("n", "<leader>cR", function() Snacks.rename.rename_file() end, { desc = "Rename File" })
vim.keymap.set({ "n", "v" }, "<leader>gB", function() Snacks.gitbrowse() end, { desc = "Git Browse" })
vim.keymap.set("n", "<leader>gg", function() Snacks.lazygit() end, { desc = "Lazygit" })
vim.keymap.set("n", "<leader>un", function() Snacks.notifier.hide() end, { desc = "Dismiss All Notifications" })
vim.keymap.set("n", "<c-/>", function() Snacks.terminal() end, { desc = "Toggle Terminal" })
vim.keymap.set("n", "<c-_>", function() Snacks.terminal() end, { desc = "which_key_ignore" })
vim.keymap.set({ "n", "t" }, "]]", function() Snacks.words.jump(vim.v.count1) end, { desc = "Next Reference" })
vim.keymap.set({ "n", "t" }, "[[", function() Snacks.words.jump(-vim.v.count1) end, { desc = "Prev Reference" })
vim.keymap.set("n", "<leader>N", function()
  Snacks.win({
    file = vim.api.nvim_get_runtime_file("doc/news.txt", false)[1],
    width = 0.6,
    height = 0.6,
    wo = {
      spell = false,
      wrap = false,
      signcolumn = "yes",
      statuscolumn = " ",
      conceallevel = 3,
    },
  })
end, { desc = "Neovim News" })
  -- snack.nvim --
end
