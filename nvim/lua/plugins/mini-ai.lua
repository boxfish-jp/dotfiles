local ai = require("mini.ai")

ai.setup({
  n_lines = 500,
  custom_textobjects = {
    -- コードブロック
    o = ai.gen_spec.treesitter({
      a = { "@block.outer", "@conditional.outer", "@loop.outer" },
      i = { "@block.inner", "@conditional.inner", "@loop.inner" },
    }),
    -- 関数
    f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
    -- クラス
    c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
    -- HTML/XMLタグ
    t = {
      "<([%p%w]-)%f[^<%w][^<>]->.-</%1>",
      "^<.->().*()</[^/]->$",
    },
    -- 数字
    d = { "%f[%d]%d+" },
    -- キャメルケースなど対応の単語
    e = {
      {
        "%u[%l%d]+%f[^%l%d]",
        "%f[%S][%l%d]+%f[^%l%d]",
        "%f[%P][%l%d]+%f[^%l%d]",
        "^[%l%d]+%f[^%l%d]",
      },
      "^().*()$",
    },
    -- バッファ全体
    -- g = ai.gen_spec.all(),
    -- 関数呼び出し
    u = ai.gen_spec.function_call(),
    U = ai.gen_spec.function_call({ name_pattern = "[%w_]" }),
  },
})
