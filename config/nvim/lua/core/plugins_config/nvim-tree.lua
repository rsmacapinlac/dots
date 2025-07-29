require("nvim-tree").setup({
  sort = {
    sorter = "case_sensitive",
  },
  view = {
    width = 30,
  },
  renderer = {
    group_empty = true,
  },
  filters = {
    dotfiles = false,
  },
})

-- Keybindings
vim.keymap.set('n', '<C-n>', ':NvimTreeToggle<CR>', { silent = true })
vim.keymap.set('n', '<leader>r', ':NvimTreeRefresh<CR>', { silent = true })
vim.keymap.set('n', '<leader>n', ':NvimTreeFindFile<CR>', { silent = true })