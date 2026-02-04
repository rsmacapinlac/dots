-- setup builtins for telescope
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<C-p>', function() builtin.find_files({ no_ignore = true }) end, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
