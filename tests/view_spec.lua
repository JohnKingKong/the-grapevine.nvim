-- tests/view_spec.lua
describe("the-grapevine.view", function()
  local view

  before_each(function()
    package.loaded["the-grapevine.view"] = nil
    view = require("the-grapevine.view")
  end)

  describe("render", function()
    local grouped = {
      {
        file = "src/a.lua",
        threads = {
          {
            file = "src/a.lua",
            line = 10,
            resolved = false,
            comments = { { author = "reviewer1", body = "why is this here?", created_at = "2026-01-01T00:00:00Z" } },
          },
          {
            file = "src/a.lua",
            line = 20,
            resolved = true,
            comments = { { author = "reviewer2", body = "typo", created_at = "2026-01-02T00:00:00Z" } },
          },
        },
      },
      {
        file = "src/b.lua",
        threads = {
          {
            file = "src/b.lua",
            line = 5,
            resolved = false,
            comments = { { author = "reviewer1", body = "extract this", created_at = "2026-01-03T00:00:00Z" } },
          },
        },
      },
    }

    it("includes a header line per file", function()
      local lines = view.render(grouped, true)
      local joined = table.concat(lines, "\n")
      assert.is_true(joined:find("src/a%.lua") ~= nil)
      assert.is_true(joined:find("src/b%.lua") ~= nil)
    end)

    it("shows every thread's author, line, and body when show_resolved is true", function()
      local lines = view.render(grouped, true)
      local joined = table.concat(lines, "\n")
      assert.is_true(joined:find("reviewer1") ~= nil)
      assert.is_true(joined:find("reviewer2") ~= nil)
      -- plain=true: the body text contains "?", a Lua pattern special
      -- character (0-or-1 quantifier) that would otherwise silently
      -- change what this is actually matching.
      assert.is_true(joined:find("why is this here?", 1, true) ~= nil)
      assert.is_true(joined:find("typo") ~= nil)
    end)

    it("hides resolved threads when show_resolved is false", function()
      local lines = view.render(grouped, false)
      local joined = table.concat(lines, "\n")
      assert.is_true(joined:find("why is this here?", 1, true) ~= nil)
      assert.is_nil(joined:find("typo"))
    end)

    it("omits a file header entirely if every thread in it is filtered out", function()
      local single_resolved = {
        {
          file = "src/only.lua",
          threads = {
            {
              file = "src/only.lua",
              line = 1,
              resolved = true,
              comments = { { author = "a", body = "x", created_at = "2026-01-01T00:00:00Z" } },
            },
          },
        },
      }
      local lines = view.render(single_resolved, false)
      local joined = table.concat(lines, "\n")
      assert.is_nil(joined:find("src/only%.lua"))
    end)

    it("returns targets keyed by line number, present on comment lines, absent on header lines", function()
      -- targets is a sparse table (keyed by 1-indexed line number), not a
      -- parallel array -- table.insert(array, nil) silently drops the
      -- insert instead of leaving a hole (confirmed empirically: it
      -- desyncs any later inserts), so a header line's "no target" is
      -- represented by the key simply being absent, not by an explicit
      -- nil entry at the right position. #lines (a true array, no holes)
      -- is the only reliable iteration bound here -- #targets on a table
      -- with only some keys set is undefined.
      local lines, targets = view.render(grouped, true)

      local found = false
      for i = 1, #lines do
        local target = targets[i]
        if target and target.file == "src/a.lua" and target.line == 10 then
          found = true
          assert.is_true(lines[i]:find("reviewer1") ~= nil or lines[i]:find("why is this here?", 1, true) ~= nil)
        end
      end
      assert.is_true(found, "expected a target pointing at src/a.lua:10")

      -- The very first line is always a file header (M.render's first
      -- add(group.file, nil) call for the first visible group) and must
      -- have no target.
      assert.is_nil(targets[1])
    end)

    it("returns an empty render for an empty grouped list", function()
      local lines, targets = view.render({}, true)
      assert.are.same({}, lines)
      assert.are.same({}, targets)
    end)

    it("inserts a blank line between threads in the same file, and between files", function()
      local lines = view.render(grouped, true)
      -- src/a.lua's two threads (unresolved, resolved) should have a blank
      -- line between them, and its last thread should have a blank line
      -- before src/b.lua's header -- but no trailing blank line at the
      -- very end.
      local blank_indices = {}
      for i, line in ipairs(lines) do
        if line == "" then
          table.insert(blank_indices, i)
        end
      end
      assert.are.equal(
        2,
        #blank_indices,
        "expected exactly 2 blank lines (between the 2 threads in src/a.lua, and before src/b.lua's header)"
      )
      assert.are_not.equal(
        #lines,
        blank_indices[#blank_indices],
        "the last line must not be blank (trailing blank trimmed)"
      )
    end)

    it("returns highlight metadata for the file header, author, resolved mark, and location", function()
      local lines, _, highlights = view.render(grouped, true)

      local function find(hl_group, line)
        for _, h in ipairs(highlights) do
          if h.hl_group == hl_group and h.line == line then
            return h
          end
        end
        return nil
      end

      -- Line 1 is always the first file header (src/a.lua).
      local file_hl = find("GrapevineFile", 1)
      assert.is_not_nil(file_hl)
      assert.are.equal(0, file_hl.col_start)
      assert.are.equal(#"src/a.lua", file_hl.col_end)
      assert.are.equal(lines[1]:sub(file_hl.col_start + 1, file_hl.col_end), "src/a.lua")

      -- Find the author/location line for the resolved thread (reviewer2)
      -- to confirm the resolved-mark highlight is present too.
      local resolved_line_no
      for i, line in ipairs(lines) do
        if line:find("reviewer2", 1, true) then
          resolved_line_no = i
          break
        end
      end
      assert.is_not_nil(resolved_line_no)

      local resolved_hl = find("GrapevineResolved", resolved_line_no)
      assert.is_not_nil(resolved_hl, "expected a GrapevineResolved highlight on the resolved thread's line")

      local author_hl = find("GrapevineAuthor", resolved_line_no)
      assert.is_not_nil(author_hl)
      assert.are.equal("reviewer2", lines[resolved_line_no]:sub(author_hl.col_start + 1, author_hl.col_end))

      local location_hl = find("GrapevineLocation", resolved_line_no)
      assert.is_not_nil(location_hl)
      assert.are.equal("src/a.lua:20", lines[resolved_line_no]:sub(location_hl.col_start + 1, location_hl.col_end))
    end)

    it("returns no highlights for an empty grouped list", function()
      local _, _, highlights = view.render({}, true)
      assert.are.same({}, highlights)
    end)
  end)
end)

describe("the-grapevine.view.open_loading / open", function()
  local view

  before_each(function()
    package.loaded["the-grapevine.view"] = nil
    view = require("the-grapevine.view")
  end)

  after_each(function()
    pcall(vim.api.nvim_win_close, view._last_win, true)
  end)

  it("open_loading shows a loading message in a floating window", function()
    view.open_loading()
    assert.is_true(vim.api.nvim_win_is_valid(view._last_win))
    local buf = vim.api.nvim_win_get_buf(view._last_win)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.is_true(table.concat(lines, "\n"):find("Loading") ~= nil)
  end)

  it("open replaces the loading window's content with the real render", function()
    view.open_loading()
    local win = view._last_win

    view.open({
      {
        file = "src/a.lua",
        threads = {
          {
            file = "src/a.lua",
            line = 1,
            resolved = false,
            comments = { { author = "a", body = "hi", created_at = "2026-01-01T00:00:00Z" } },
          },
        },
      },
    })

    assert.are.equal(win, view._last_win, "open must reuse the loading window, not open a second one")
    local buf = vim.api.nvim_win_get_buf(view._last_win)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local joined = table.concat(lines, "\n")
    assert.is_nil(joined:find("Loading"))
    assert.is_true(joined:find("src/a%.lua") ~= nil)
  end)

  it("open opens a fresh window if no loading window is open", function()
    view.open({
      {
        file = "src/a.lua",
        threads = {
          {
            file = "src/a.lua",
            line = 1,
            resolved = false,
            comments = { { author = "a", body = "hi", created_at = "2026-01-01T00:00:00Z" } },
          },
        },
      },
    })
    assert.is_true(vim.api.nvim_win_is_valid(view._last_win))
  end)

  it("enables wrap/linebreak/breakindent on the window regardless of the global default", function()
    local original_wrap = vim.o.wrap
    vim.o.wrap = false -- simulate LazyVim's global default, which disables it

    view.open({
      {
        file = "src/a.lua",
        threads = {
          {
            file = "src/a.lua",
            line = 1,
            resolved = false,
            comments = {
              { author = "a", body = "a long comment that should wrap", created_at = "2026-01-01T00:00:00Z" },
            },
          },
        },
      },
    })

    assert.is_true(vim.wo[view._last_win].wrap, "wrap must be enabled locally, independent of the global default")
    assert.is_true(vim.wo[view._last_win].linebreak)
    assert.is_true(vim.wo[view._last_win].breakindent)

    vim.o.wrap = original_wrap
  end)

  it("q closes the window", function()
    view.open({})
    local win = view._last_win
    vim.api.nvim_set_current_win(win)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("q", true, false, true), "x", false)
    assert.is_false(vim.api.nvim_win_is_valid(win))
  end)

  it("R toggles resolved threads visible, then hidden again", function()
    local grouped = {
      {
        file = "src/a.lua",
        threads = {
          {
            file = "src/a.lua",
            line = 1,
            resolved = true,
            comments = { { author = "a", body = "resolved comment", created_at = "2026-01-01T00:00:00Z" } },
          },
        },
      },
    }
    view.open(grouped)
    local win = view._last_win
    vim.api.nvim_set_current_win(win)
    local buf = vim.api.nvim_win_get_buf(win)

    local before = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    assert.is_nil(before:find("resolved comment"), "resolved threads must be hidden by default")

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("R", true, false, true), "x", false)
    local after_toggle = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    assert.is_true(after_toggle:find("resolved comment") ~= nil, "R must reveal resolved threads")

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("R", true, false, true), "x", false)
    local after_second_toggle = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    assert.is_nil(after_second_toggle:find("resolved comment"), "a second R must hide them again")
  end)

  it("<CR> on a comment line closes the window and opens that file at that line", function()
    local tmpfile = vim.fn.tempname() .. ".lua"
    vim.fn.writefile({ "one", "two", "three", "four", "five" }, tmpfile)
    -- root is a separate directory from the target file, and target.file is
    -- root-relative (as GitHub's API always returns it) -- this proves the
    -- <CR> handler actually joins state.root with target.file rather than
    -- just happening to work because the path was already absolute.
    local root = vim.fn.fnamemodify(tmpfile, ":h")
    local relative_file = vim.fn.fnamemodify(tmpfile, ":t")

    local grouped = {
      {
        file = relative_file,
        threads = {
          {
            file = relative_file,
            line = 3,
            resolved = false,
            comments = { { author = "a", body = "look here", created_at = "2026-01-01T00:00:00Z" } },
          },
        },
      },
    }
    view.open(grouped, root)
    local win = view._last_win
    vim.api.nvim_set_current_win(win)

    -- Land the cursor on the comment's body line. Search only for the
    -- body text ("look here"), not the file path -- the group's header
    -- line IS the raw file path (M.render's first `add(group.file, nil)`
    -- call) with a nil target, so a search that also matched on the file
    -- path would find that header line first and land on a dead target.
    local buf = vim.api.nvim_win_get_buf(win)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local target_row
    for i, line in ipairs(lines) do
      if line:find("look here", 1, true) then
        target_row = i
        break
      end
    end
    assert.is_not_nil(target_row, "expected to find the comment body line")
    vim.api.nvim_win_set_cursor(win, { target_row, 0 })

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)

    assert.is_false(vim.api.nvim_win_is_valid(win), "<CR> must close the grapevine window")
    -- Compare against the symlink-resolved path: Neovim's :edit
    -- canonicalizes buffer names by resolving symlinks in the path
    -- (standard behavior), and on macOS /var is a symlink to /private/var,
    -- while vim.fn.tempname() returns the unresolved /var/... form. This
    -- is deterministic on such systems and not a bug in the <CR> handler,
    -- which opens the exact right file.
    assert.are.equal(vim.fn.resolve(tmpfile), vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()))
    assert.are.equal(3, vim.api.nvim_win_get_cursor(0)[1])

    vim.fn.delete(tmpfile)
  end)

  it("<CR> clamps to the last line instead of erroring when target.line exceeds the local file's line count", function()
    -- Real-world case: GitHub recorded the comment against a line number
    -- that no longer exists locally -- the file has since shrunk, or the
    -- comment used the originalLine fallback for an outdated thread.
    -- Previously this raised E5108 "Invalid cursor line: out of range"
    -- from nvim_win_set_cursor.
    local tmpfile = vim.fn.tempname() .. ".lua"
    vim.fn.writefile({ "one", "two", "three" }, tmpfile) -- only 3 lines
    local root = vim.fn.fnamemodify(tmpfile, ":h")
    local relative_file = vim.fn.fnamemodify(tmpfile, ":t")

    local grouped = {
      {
        file = relative_file,
        threads = {
          {
            file = relative_file,
            line = 999, -- far beyond the file's actual 3 lines
            resolved = false,
            comments = { { author = "a", body = "stale line comment", created_at = "2026-01-01T00:00:00Z" } },
          },
        },
      },
    }
    view.open(grouped, root)
    local win = view._last_win
    vim.api.nvim_set_current_win(win)

    local buf = vim.api.nvim_win_get_buf(win)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local target_row
    for i, line in ipairs(lines) do
      if line:find("stale line comment", 1, true) then
        target_row = i
        break
      end
    end
    assert.is_not_nil(target_row)
    vim.api.nvim_win_set_cursor(win, { target_row, 0 })

    assert.has_no.errors(function()
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)
    end)

    assert.are.equal(vim.fn.resolve(tmpfile), vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()))
    assert.are.equal(3, vim.api.nvim_win_get_cursor(0)[1], "cursor must clamp to the last line (3), not error")

    vim.fn.delete(tmpfile)
  end)

  it("close closes the window when one is open", function()
    view.open({
      {
        file = "src/a.lua",
        threads = {
          {
            file = "src/a.lua",
            line = 1,
            resolved = false,
            comments = { { author = "a", body = "hi", created_at = "2026-01-01T00:00:00Z" } },
          },
        },
      },
    })
    local win = view._last_win
    assert.is_true(vim.api.nvim_win_is_valid(win))

    view.close()

    assert.is_false(vim.api.nvim_win_is_valid(win))
  end)

  it("close does not error when no window is open", function()
    assert.has_no.errors(function()
      view.close()
    end)
  end)
end)
