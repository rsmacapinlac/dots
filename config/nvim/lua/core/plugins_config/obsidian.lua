require("obsidian").setup({
  workspaces = {
    {
      name = "Second Brain",
      path = "~/Second Brain",
    },
  },
  
  -- Template configuration
  --templates = {
  --  subdir = "core/templates",
  --  date_format = "%Y-%m-%d",
  --  time_format = "%H:%M",
    -- Custom substitutions
  --  substitutions = {},
  --},

  -- Note ID function - preserve spaces and only remove filesystem-invalid characters
  note_id_func = function(title)
    if title ~= nil then
      -- Only remove characters that are invalid on Linux filesystems
      -- Keep spaces, parentheses, and other valid characters
      return title:gsub("[/\\:*?\"<>|]", "")
    else
      -- Fallback if no title provided
      return tostring(os.time())
    end
  end,
  
  -- Completely disable frontmatter management
  disable_frontmatter = true,
  opts = {
    picker = {
      -- Set your preferred picker. Can be one of 'telescope.nvim', 'fzf-lua', or 'mini.pick'.
      name = "telescope.nvim",
      -- Optional, configure key mappings for the picker. These are the defaults.
      -- Not all pickers support all mappings.
      note_mappings = {
        -- Create a new note from your query.
        new = "<C-x>",
        -- Insert a link to the selected note.
        insert_link = "<C-l>",
      },
      tag_mappings = {
        -- Add tag(s) to current note.
        tag_note = "<C-x>",
        -- Insert a tag at the current location.
        insert_tag = "<C-l>",
      },
    },
    completion = {
      -- Set to false to disable completion.
      nvim_cmp = true,
      -- Trigger completion at 2 chars.
      min_chars = 2,
    },
  },
})
