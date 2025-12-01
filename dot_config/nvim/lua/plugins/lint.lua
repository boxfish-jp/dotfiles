local severities = {
  [0] = vim.diagnostic.severity.INFO,
  [1] = vim.diagnostic.severity.WARN,
  [2] = vim.diagnostic.severity.ERROR,
}

local binary_name = "textlint"

return {
  {
    "mfussenegger/nvim-lint",
    event = "LazyFile",

    opts = {
      -- Event to trigger linters
      linters_by_ft = {
        -- Use the "*" filetype to run linters on all filetypes.
        -- ['*'] = { 'global linter' },
        -- Use the "_" filetype to run linters on filetypes that don't have other linters configured.
        -- ['_'] = { 'fallback linter' },
        -- ["*"] = { "typos" },
        markdown = { "textlint" },

      },
      linters = {
        textlint = {
          cmd = function()
            local local_binary = vim.fn.fnamemodify('./node_modules/.bin/' .. binary_name, ':p')
            return vim.loop.fs_stat(local_binary) and local_binary or binary_name
          end,
          stdin = true,
          args = {
            "--format",
            "json",
            "--stdin",
            "--stdin-filename",
            function()
              return vim.api.nvim_buf_get_name(0)
            end,
          },
          ignore_exitcode = true,
          stream = "stdout",
          parser = function(output)
            if output == "" then
              return {}
            end
            local decoded = vim.json.decode(output)
            if decoded == nil then
              return {}
            end
            local diagnostics = {}
            for _, value in ipairs(decoded) do
              for _, item in ipairs(value.messages) do
                table.insert(diagnostics, {
                  message = item.message,
                  col = item.loc.start.column - 1,
                  end_col = item.loc["end"].column - 1,
                  lnum = item.loc.start.line - 1,
                  end_lnum = item.loc["end"].line - 1,
                  severity = severities[item.severity],
                  source = "textlint",
                })
              end
            end
            return diagnostics
          end
        }
      }
    }
  }
}
