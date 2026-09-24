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

    local grouped = {
      {
        file = tmpfile,
        threads = {
          {
            file = tmpfile,
            line = 3,
            resolved = false,
            comments = { { author = "a", body = "look here", created_at = "2026-01-01T00:00:00Z" } },
          },
        },
      },
    }
    view.open(grouped)
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
end)
