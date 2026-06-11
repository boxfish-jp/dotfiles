do
  -- [[ 基本的なキーマップ ]]
  -- 詳細は `:help vim.keymap.set()` を参照

  -- ノーマルモードで <Esc> を押したときに検索ハイライトをクリアする
  -- 詳細は `:help hlsearch` を参照
  -- vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

  -- 診断（Diagnostic）の設定とキーマップ
  -- 詳細は `:help vim.diagnostic.Opts` を参照
  vim.diagnostic.config({
    update_in_insert = false,
    severity_sort = true,
    float = { border = "rounded", source = "if_many" },
    underline = { severity = { min = vim.diagnostic.severity.WARN } },

    -- 好みに応じてこれらを切り替えることができます
    virtual_text = true, -- テキストが行末に表示されます
    virtual_lines = false, -- テキストが仮想行として行の下に表示されます

    -- フロートウィンドウを自動で開き、`[d` や `]d` でジャンプした際にエラーを簡単に読めるようにします
    jump = {
      on_jump = function(_, bufnr)
        vim.diagnostic.open_float({
          bufnr = bufnr,
          scope = "cursor",
          focus = false,
        })
      end,
    },
  })
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
  vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "左のウィンドウにフォーカスを移動" })
  vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "右のウィンドウにフォーカスを移動" })
  vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "下のウィンドウにフォーカスを移動" })
  vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "上のウィンドウにフォーカスを移動" })

  vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "診断 [Q]uickfix リストを開く" })
  -- テキストをヤンク（コピー）したときにハイライト表示する
  -- ノーマルモードで `yap` などを試してみてください
  -- 詳細は `:help vim.hl.on_yank()` を参照

  vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "ヤンク（コピー）時にテキストをハイライト",
    group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
    callback = function()
      vim.hl.on_yank()
    end,
  })
end
