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
