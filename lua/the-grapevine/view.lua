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

M._last_win = nil
local state = { buf = nil, win = nil, grouped = {}, show_resolved = false, targets = {}, origin_win = nil, root = nil }

local function open_float(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local width = math.floor(vim.o.columns * 0.7)
  local height = math.floor(vim.o.lines * 0.6)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    border = "rounded",
    title = " the grapevine ",
    footer = " R toggle resolved  <CR> jump  q close ",
    footer_pos = "left",
  })

  local opts = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set("n", "q", function()
    pcall(vim.api.nvim_win_close, win, true)
  end, opts)
  vim.keymap.set("n", "<Esc>", function()
    pcall(vim.api.nvim_win_close, win, true)
  end, opts)
  vim.keymap.set("n", "R", function()
    state.show_resolved = not state.show_resolved
    local new_lines, new_targets = M.render(state.grouped, state.show_resolved)
    state.targets = new_targets
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
    vim.bo[buf].modifiable = false
  end, opts)
  vim.keymap.set("n", "<CR>", function()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local target = state.targets[row]
    if not target then
      return
    end
    pcall(vim.api.nvim_win_close, win, true)
    if state.origin_win and vim.api.nvim_win_is_valid(state.origin_win) then
      vim.api.nvim_set_current_win(state.origin_win)
    end
    local path = (state.root and state.root ~= "") and (state.root .. "/" .. target.file) or target.file
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    if target.line then
      vim.api.nvim_win_set_cursor(0, { target.line, 0 })
    end
  end, opts)

  return buf, win
end

function M.open_loading()
  state.origin_win = vim.api.nvim_get_current_win()
  state.grouped = {}
  state.show_resolved = false
  state.targets = {}
  state.root = nil
  state.buf, state.win = open_float({ "Loading PR comments…" })
  M._last_win = state.win
end

function M.open(grouped_threads, root)
  state.grouped = grouped_threads
  state.root = root
  state.show_resolved = false
  local lines, targets = M.render(grouped_threads, state.show_resolved)
  state.targets = targets

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.bo[state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    vim.bo[state.buf].modifiable = false
  else
    state.origin_win = state.origin_win or vim.api.nvim_get_current_win()
    state.buf, state.win = open_float(lines)
  end
  M._last_win = state.win
end

function M.close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
  end
end

return M
