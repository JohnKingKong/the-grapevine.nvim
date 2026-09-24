-- lua/the-grapevine/view.lua
local M = {}

local RESOLVED_MARK = "✓ "

function M.render(grouped_threads, show_resolved)
  local lines = {}
  -- Sparse table keyed by line number, NOT a parallel array: table.insert
  -- with a nil value silently drops the insert instead of leaving a hole
  -- (verified empirically -- it desyncs every subsequent insert), so a
  -- "no target" line is represented by the key being absent, never by an
  -- explicit nil entry at the matching position.
  local targets = {}

  local function add(line, target)
    table.insert(lines, line)
    if target then
      targets[#lines] = target
    end
  end

  for _, group in ipairs(grouped_threads) do
    local visible_threads = {}
    for _, thread in ipairs(group.threads) do
      if show_resolved or not thread.resolved then
        table.insert(visible_threads, thread)
      end
    end

    if #visible_threads > 0 then
      add(group.file, nil)
      for _, thread in ipairs(visible_threads) do
        local resolved_mark = thread.resolved and RESOLVED_MARK or ""
        for _, comment in ipairs(thread.comments) do
          add(
            string.format("  %s%s  %s:%s", resolved_mark, comment.author, thread.file, tostring(thread.line)),
            { file = thread.file, line = thread.line }
          )
          for body_line in comment.body:gmatch("[^\n]+") do
            add("    " .. body_line, { file = thread.file, line = thread.line })
          end
        end
      end
    end
  end

  return lines, targets
end

return M
