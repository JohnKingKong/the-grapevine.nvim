-- plugin/the-grapevine.lua
if vim.g.loaded_the_grapevine then
  return
end
vim.g.loaded_the_grapevine = true

vim.api.nvim_create_user_command("Grapevine", function()
  require("the-grapevine").open()
end, { desc = "Show the current branch's PR review comments" })
