-- tests/minimal_init.lua
vim.opt.rtp:append(".")
vim.opt.rtp:append(".deps/plenary.nvim")

vim.opt.swapfile = false

vim.cmd("runtime! plugin/plenary.vim")
