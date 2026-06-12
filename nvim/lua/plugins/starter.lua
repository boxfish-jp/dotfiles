local starter = require("mini.starter")

local ascii_art = {
  "███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗",
  "████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║",
  "██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║",
  "██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║",
  "██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║",
  "╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
}

local startup_time = function()
  local elapsed = (vim.loop.now() - vim.g.startup_time) / 1000
  if elapsed < 100 then
    return string.format("⚡ Fast startup: %.1f ms", elapsed)
  elseif elapsed < 200 then
    return string.format("⏱  Startup completed in %.1f ms", elapsed)
  else
    return string.format("🐌 Slow startup: %.2f s", elapsed)
  end
end

-- アスキーアートを追加するフック
local hook_add_ascii_art = function(content)
  local ascii_items = {}
  for _, line in ipairs(ascii_art) do
    table.insert(ascii_items, {
      { type = "string", string = line, ascii = true },
    })
  end
  table.insert(ascii_items, { { type = "empty", string = "" } })

  for i = #ascii_items, 1, -1 do
    table.insert(content, 1, ascii_items[i])
  end
  return content
end

starter.setup({
  evaluate_single = true,
  items = {
    starter.sections.builtin_actions(),
    starter.sections.recent_files(10, true),
  },
  footer = startup_time,
  content_hooks = {
    hook_add_ascii_art,
    starter.gen_hook.aligning("center", "center"),
    starter.gen_hook.adding_bullet(nil, function(item)
      return not item.ascii
    end),
    starter.gen_hook.indexing("all", { "Builtin actions" }),
    starter.gen_hook.padding(3, 2),
  },
})
