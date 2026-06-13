local icons = {
  Error = "",
  Warn  = "",
  Hint  = "",
  Info  = "",
}

vim.diagnostic.config({
  underline = true,
  virtual_text = {
    spacing = 4,
    source = "if_many",
    prefix = function(diagnostic)
      local sev = diagnostic.severity
      if sev == vim.diagnostic.severity.ERROR then return icons.Error
      elseif sev == vim.diagnostic.severity.WARN then return icons.Warn
      elseif sev == vim.diagnostic.severity.HINT then return icons.Hint
      elseif sev == vim.diagnostic.severity.INFO then return icons.Info
      end
      return "●"
    end,
  },
  severity_sort = true,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = icons.Error,
      [vim.diagnostic.severity.WARN]  = icons.Warn,
      [vim.diagnostic.severity.HINT]  = icons.Hint,
      [vim.diagnostic.severity.INFO]  = icons.Info,
    },
  },
})

vim.lsp.enable('clangd')      -- C/C++

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    local opts = { buffer = ev.buf, noremap = true, silent = true }
    local map = vim.keymap.set

    -- 定義ジャンプ
    map('n', 'gd', vim.lsp.buf.definition, opts)
    map('n', 'gr', vim.lsp.buf.references, opts)
    map('n', 'gI', vim.lsp.buf.implementation, opts)
    map('n', 'gy', vim.lsp.buf.type_definition, opts)
    map('n', 'gD', vim.lsp.buf.declaration, opts)

    -- ホバー／シグネチャヘルプ
    map('n', 'K', vim.lsp.buf.hover, opts)
    map('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    map('i', '<C-k>', vim.lsp.buf.signature_help, opts)

    -- コードアクション
    map({ 'n', 'x' }, '<leader>ca', vim.lsp.buf.code_action, opts)

    -- リネーム
    map('n', '<leader>cr', vim.lsp.buf.rename, opts)

    -- フォーマット（任意）
    map('n', '<leader>cf', function() vim.lsp.buf.format({ async = true }) end, opts)

    local bufnr = ev.buf 
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client.server_capabilities.inlayHintProvider then
      vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
    end
  end,
})
