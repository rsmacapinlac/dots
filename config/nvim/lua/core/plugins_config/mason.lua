
require("mason").setup()
require("mason-lspconfig").setup {
  ensure_installed = { "lua_ls", "ansiblels", "gopls" }
}

vim.lsp.enable('gopls')
