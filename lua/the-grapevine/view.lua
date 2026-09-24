-- lua/the-grapevine/view.lua
local M = {}

local RESOLVED_MARK = "✓ "

-- Linked (not hardcoded) to existing highlight groups so this adapts to
-- whatever colorscheme is active, rather than fighting it with fixed
-- colors. default = true means a user's own override of these group
-- names (if they ever set one) always wins.
local function define_highlights()
  vim.api.nvim_set_hl(0, "GrapevineFile", { link = "Title", default = true })
  vim.api.nvim_set_hl(0, "GrapevineAuthor", { link = "Function", default = true })
  vim.api.nvim_set_hl(0, "GrapevineLocation", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "GrapevineResolved", { link = "DiagnosticOk", default = true })
end
define_highlights()

-- (lines, targets, highlights): highlights is a list of
-- { line = <1-indexed>, col_start, col_end = <0-indexed byte columns>,
-- hl_group }, applied via extmarks by the caller -- render() itself never
-- touches a buffer, staying a pure (grouped, show_resolved) -> data
-- transform.
function M.render(grouped_threads, show_resolved)
  local lines = {}
  -- Sparse table keyed by line number, NOT a parallel array: table.insert
  -- with a nil value silently drops the insert instead of leaving a hole
  -- (verified empirically -- it desyncs every subsequent insert), so a
  -- "no target" line is represented by the key being absent, never by an
  -- explicit nil entry at the matching position.
  local targets = {}
  local highlights = {}

  local function add(line, target)
    table.insert(lines, line)
    if target then
      targets[#lines] = target
    end
  end

  local function add_highlight(hl_group, col_start, col_end)
    table.insert(highlights, { line = #lines, hl_group = hl_group, col_start = col_start, col_end = col_end })
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
      add_highlight("GrapevineFile", 0, #group.file)

      for _, thread in ipairs(visible_threads) do
        local resolved_mark = thread.resolved and RESOLVED_MARK or ""
        local location = thread.file .. ":" .. tostring(thread.line)
        for _, comment in ipairs(thread.comments) do
          local prefix = "  "
          add(prefix .. resolved_mark .. comment.author .. "  " .. location, { file = thread.file, line = thread.line })

          local col = #prefix
          if thread.resolved then
            add_highlight("GrapevineResolved", col, col + #RESOLVED_MARK)
            col = col + #RESOLVED_MARK
          end
          add_highlight("GrapevineAuthor", col, col + #comment.author)
          col = col + #comment.author + 2 -- skip the "  " separator before location
          add_highlight("GrapevineLocation", col, col + #location)

          for body_line in comment.body:gmatch("[^\n]+") do
            add("    " .. body_line, { file = thread.file, line = thread.line })
          end
        end
        -- Blank line after every thread -- between threads in the same
        -- file, and between a file's last thread and the next file's
        -- header, giving consistent breathing room either way. The one
        -- trailing blank line this leaves after the very last thread
        -- overall is trimmed below.
        add("")
      end
    end
  end

  if lines[#lines] == "" then
    table.remove(lines)
  end

  return lines, targets, highlights
end

M._last_win = nil
local state = { buf = nil, win = nil, grouped = {}, show_resolved = false, targets = {}, origin_win = nil, root = nil }

local NAMESPACE = vim.api.nvim_create_namespace("the_grapevine")

local function apply_highlights(buf, highlights)
  vim.api.nvim_buf_clear_namespace(buf, NAMESPACE, 0, -1)
  for _, h in ipairs(highlights) do
    vim.api.nvim_buf_set_extmark(buf, NAMESPACE, h.line - 1, h.col_start, {
      end_col = h.col_end,
      hl_group = h.hl_group,
    })
  end
end

local function open_float(lines, highlights)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  apply_highlights(buf, highlights or {})

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

  -- LazyVim (and many configs) disable 'wrap' globally for a code-editor
  -- feel; this window shows prose-like comment bodies, so it needs its
  -- own local override rather than inheriting that. linebreak wraps at
  -- word boundaries instead of mid-word; breakindent aligns a wrapped
  -- continuation with its line's own indent instead of column 0.
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].breakindent = true

  local opts = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set("n", "q", function()
    pcall(vim.api.nvim_win_close, win, true)
  end, opts)
  vim.keymap.set("n", "<Esc>", function()
    pcall(vim.api.nvim_win_close, win, true)
  end, opts)
  vim.keymap.set("n", "R", function()
    state.show_resolved = not state.show_resolved
    local new_lines, new_targets, new_highlights = M.render(state.grouped, state.show_resolved)
    state.targets = new_targets
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
    vim.bo[buf].modifiable = false
    apply_highlights(buf, new_highlights)
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
      -- target.line is the line number GitHub recorded the comment
      -- against, which can be stale by the time you actually jump here --
      -- the local file may have changed (or the comment used
      -- originalLine, an outdated-thread fallback) since then. Clamping
      -- instead of erroring lands on the closest valid line rather than
      -- crashing E5108 on an out-of-range cursor position.
      local line_count = vim.api.nvim_buf_line_count(0)
      local clamped_line = math.max(1, math.min(target.line, line_count))
      vim.api.nvim_win_set_cursor(0, { clamped_line, 0 })
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
  local lines, targets, highlights = M.render(grouped_threads, state.show_resolved)
  state.targets = targets

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.bo[state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    vim.bo[state.buf].modifiable = false
    apply_highlights(state.buf, highlights)
  else
    state.origin_win = state.origin_win or vim.api.nvim_get_current_win()
    state.buf, state.win = open_float(lines, highlights)
  end
  M._last_win = state.win
end

function M.close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
  end
end

return M
