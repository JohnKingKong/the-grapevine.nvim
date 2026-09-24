-- lua/the-grapevine/init.lua
local M = {}

function M.setup(_opts) end

function M.open()
  if vim.fn.executable("gh") == 0 then
    vim.notify("the-grapevine: the 'gh' CLI is not installed or not on PATH", vim.log.levels.ERROR)
    return
  end

  local view = require("the-grapevine.view")
  local gh = require("the-grapevine.gh")

  view.open_loading()

  gh.find_pr(function(pr, find_err)
    if not pr then
      view.close()
      vim.notify("the-grapevine: " .. find_err, vim.log.levels.ERROR)
      return
    end

    gh.fetch_threads(pr, function(raw_threads, fetch_err)
      if not raw_threads then
        view.close()
        vim.notify("the-grapevine: " .. fetch_err, vim.log.levels.ERROR)
        return
      end

      local grouped = require("the-grapevine.parse").group_by_file(raw_threads)
      view.open(grouped)
    end)
  end)
end

return M
