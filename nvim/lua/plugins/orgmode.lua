require("orgmode").setup({
  org_agenda_files = "~/orgfiles/**/*",
  org_default_notes_file = "~/orgfiles/refile.org",
  org_todo_keywords = {
    { "TODO", "THINKING", "DEVELOPING", "TEST", "BUILDING", "|", "DONE", "CANCELED" },
  },
  org_todo_keyword_faces = {
    TODO = ":foreground orange :weight bold",
    THINKING = ":foreground orange :weight bold",
    DEVELOPING = ":foreground deep sky blue :weight bold",
    TEST = ":foreground magenta :weight bold",
    BUILDING = ":foreground goldenrod :weight bold",
    DONE = ":foreground green :weight bold",
    CANCELED = ":foreground gray :weight bold",
  },
  org_log_done = "time",
  mappings = {
    org = {
      org_todo = "<leader>ot",
      org_todo_prev = "<leader>oT",
    },
  },
})
