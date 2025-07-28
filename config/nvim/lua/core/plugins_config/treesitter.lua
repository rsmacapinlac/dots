local config = require("nvim-treesitter.configs")
config.setup({
  ensure_installed = {"lua", "javascript", "markdown", "markdown_inline"},
  highlight = { enable = true },
  indent = { enable = true }
})
