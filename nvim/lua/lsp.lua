vim.lsp.config("lua_ls", {
  on_init = function(client)
    if client.workspace_folders then
      local path = client.workspace_folders[1].name
      if
        path ~= vim.fn.stdpath("config")
        and (vim.uv.fs_stat(path .. "/.luarc.json") or vim.uv.fs_stat(path .. "/.luarc.jsonc"))
      then
        return
      end
    end

    client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, {
      runtime = {
        version = "LuaJIT",
        path = { "lua/?.lua", "lua/?/init.lua" },
      },
      workspace = {
        checkThirdParty = false,
        library = {
          vim.env.VIMRUNTIME,
          vim.api.nvim_get_runtime_file("lua/lspconfig", false)[1],
        },
      },
    })
  end,
  settings = {
    Lua = {
      codeLens = { enable = true },
      hint = { enable = true, semicolon = "Disable" },
    },
  },
})
vim.lsp.enable("lua_ls")

vim.lsp.enable("copilot")
vim.lsp.enable("clangd")
vim.lsp.enable("biome")
vim.lsp.enable("ts_ls")
vim.lsp.enable("dartls")
vim.lsp.enable("nixd")

local icons = {
  Error = "",
  Warn = "",
  Hint = "",
  Info = "",
}

vim.diagnostic.config({
  underline = true,
  virtual_text = {
    spacing = 4,
    source = "if_many",
    prefix = function(diagnostic)
      local sev = diagnostic.severity
      if sev == vim.diagnostic.severity.ERROR then
        return icons.Error
      elseif sev == vim.diagnostic.severity.WARN then
        return icons.Warn
      elseif sev == vim.diagnostic.severity.HINT then
        return icons.Hint
      elseif sev == vim.diagnostic.severity.INFO then
        return icons.Info
      end
      return "●"
    end,
  },
  severity_sort = true,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = icons.Error,
      [vim.diagnostic.severity.WARN] = icons.Warn,
      [vim.diagnostic.severity.HINT] = icons.Hint,
      [vim.diagnostic.severity.INFO] = icons.Info,
    },
  },
})

vim.lsp.config("copilot", {
  cmd = { "copilot-language-server", "--stdio" },
  filetypes = { "*" },
  root_markers = { ".git" },
  on_attach = function(client, bufnr)
    local opts = { buffer = bufnr, noremap = true, silent = true }
    vim.keymap.set({ "i", "n" }, "<M-]>", function()
      vim.lsp.inline_completion.select({ count = 1 })
    end, opts)
    vim.keymap.set({ "i", "n" }, "<M-[>", function()
      vim.lsp.inline_completion.select({ count = -1 })
    end, opts)
  end,
  handlers = {
    didChangeStatus = function(err, res, ctx)
      if err then
        return
      end
      -- ステータスを保持（任意）
      if not vim.g.copilot_status then
        vim.g.copilot_status = {}
      end
      vim.g.copilot_status[ctx.client_id] = res.kind ~= "Normal" and "error" or res.busy and "pending" or "ok"
      if res.status == "Error" then
        vim.notify("Please use `:LspCopilotSignIn` to sign in to Copilot", vim.log.levels.ERROR)
      end
    end,
  },
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", {}),
  callback = function(ev)
    local opts = { buffer = ev.buf, noremap = true, silent = true }
    local map = vim.keymap.set

    -- 定義ジャンプ
    map("n", "gd", vim.lsp.buf.definition, opts)
    map("n", "gr", vim.lsp.buf.references, opts)
    map("n", "gI", vim.lsp.buf.implementation, opts)
    map("n", "gy", vim.lsp.buf.type_definition, opts)
    map("n", "gD", vim.lsp.buf.declaration, opts)

    -- ホバー／シグネチャヘルプ
    map("n", "K", vim.lsp.buf.hover, opts)
    map("n", "<C-k>", vim.lsp.buf.signature_help, opts)
    map("i", "<C-k>", vim.lsp.buf.signature_help, opts)

    -- コードアクション
    map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, opts)

    -- リネーム
    map("n", "<leader>cr", vim.lsp.buf.rename, opts)

    -- インラインヒント（サーバが対応していれば自動有効）
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client.server_capabilities.inlayHintProvider then
      vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
    end
  end,
})

-- インライン補完（Copilotのグレーのサジェスト）を有効化
vim.schedule(function()
  pcall(vim.lsp.inline_completion.enable)
end)

-- （オプション）nvim-cmp などから呼び出すためのグローバル関数
_G.ai_accept = function()
  return vim.lsp.inline_completion.get()
end
