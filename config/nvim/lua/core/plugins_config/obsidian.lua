require("obsidian").setup({
  workspaces = {
    {
      name = "Second Brain",
      path = "~/Second Brain",
    },
  },
  opts = {
    completion = {
      -- Set to false to disable completion.
      nvim_cmp = true,
      -- Trigger completion at 2 chars.
      min_chars = 2,
    },
  },
})
