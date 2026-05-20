vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- fat finger
vim.cmd [[command! Qw :qw]]
vim.cmd [[command! Q :q]]
vim.cmd [[command! W :w]]

vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float)
