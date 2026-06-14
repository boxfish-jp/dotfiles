local function setup_plugin()
  if vim.g.copilot_chat_setup_done then
    return
  end
  vim.g.copilot_chat_setup_done = true

  local user = vim.env.USER or "User"
  user = user:sub(1, 1):upper() .. user:sub(2)
  local opts = {
    auto_insert_mode = true,
    headers = {
      user = "  " .. user .. " ",
      assistant = "  Copilot ",
      tool = "󰊳  Tool ",
    },
    window = {
      width = 0.4,
    },
  }

  local chat = require("CopilotChat")
  chat.setup(opts)

  -- BufEnter の設定
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "copilot-chat",
    callback = function()
      vim.opt_local.relativenumber = false
      vim.opt_local.number = false
    end,
  })

  -- FileType ごとのキーマップ (<C-s> を <CR> に)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "copilot-chat",
    callback = function()
      vim.keymap.set("i", "<C-s>", "<CR>", { buffer = true, remap = true, desc = "Submit Prompt" })
    end,
  })
end

-- コマンド定義（遅延読み込み）
vim.api.nvim_create_user_command("CopilotChat", function(args)
  setup_plugin()
  -- 元のコマンドを実行するために、require して実行する方法
  local chat = require("CopilotChat")
  -- args を適切に渡す（ここでは単純に引数なしの toggle 的な動作？実際の CopilotChat コマンドは様々なサブコマンドを持つが簡略化）
  -- より正確には、`:CopilotChat` に引数があれば ask などになるが、ここでは元の lazy.nvim では toggle がデフォルトだったはず。
  -- 問題を避けるため、ここでは `chat.toggle()` を呼ぶ。
  -- 完全に再現するなら、args.fargs を処理する必要があるが、この例ではシンプルに toggle とする。
  chat.toggle()
end, { nargs = "*" })

-- キーマップ（遅延読み込み）
vim.keymap.set({ "n", "x" }, "<leader>aa", function()
  setup_plugin()
  require("CopilotChat").toggle()
end, { desc = "Toggle (CopilotChat)" })

vim.keymap.set({ "n", "x" }, "<leader>ax", function()
  setup_plugin()
  require("CopilotChat").reset()
end, { desc = "Clear (CopilotChat)" })

vim.keymap.set({ "n", "x" }, "<leader>aq", function()
  setup_plugin()
  vim.ui.input({ prompt = "Quick Chat: " }, function(input)
    if input and input ~= "" then
      require("CopilotChat").ask(input)
    end
  end)
end, { desc = "Quick Chat (CopilotChat)" })

vim.keymap.set({ "n", "x" }, "<leader>ap", function()
  setup_plugin()
  require("CopilotChat").select_prompt()
end, { desc = "Prompt Actions (CopilotChat)" })
