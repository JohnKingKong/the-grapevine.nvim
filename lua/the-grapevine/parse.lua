-- lua/the-grapevine/parse.lua
local M = {}

local function normalize_thread(raw)
  -- GitHub's GraphQL API returns JSON null as vim.NIL when decoded via
  -- vim.json.decode, not Lua nil -- line ~= nil is true even when the API
  -- sent null, so this checks for both.
  local line = raw.line
  if line == nil or line == vim.NIL then
    line = raw.originalLine
  end
  if line == vim.NIL then
    line = nil
  end

  local comments = {}
  for _, comment in ipairs(raw.comments.nodes) do
    table.insert(comments, {
      author = comment.author.login,
      body = comment.body,
      created_at = comment.createdAt,
    })
  end

  return {
    file = raw.path,
    line = line,
    resolved = raw.isResolved,
    comments = comments,
  }
end

function M.group_by_file(raw_threads)
  local order = {}
  local by_file = {}

  for _, raw in ipairs(raw_threads) do
    local thread = normalize_thread(raw)
    if not by_file[thread.file] then
      by_file[thread.file] = {}
      table.insert(order, thread.file)
    end
    table.insert(by_file[thread.file], thread)
  end

  table.sort(order)

  local grouped = {}
  for _, file in ipairs(order) do
    table.insert(grouped, { file = file, threads = by_file[file] })
  end
  return grouped
end

return M
