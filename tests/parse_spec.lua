-- tests/parse_spec.lua
describe("the-grapevine.parse", function()
  local parse

  before_each(function()
    package.loaded["the-grapevine.parse"] = nil
    parse = require("the-grapevine.parse")
  end)

  describe("group_by_file", function()
    it("groups threads by file, sorted alphabetically", function()
      local grouped = parse.group_by_file({
        {
          isResolved = false,
          path = "src/b.lua",
          line = 5,
          comments = { nodes = { { author = { login = "a" }, body = "x", createdAt = "2026-01-01T00:00:00Z" } } },
        },
        {
          isResolved = false,
          path = "src/a.lua",
          line = 1,
          comments = { nodes = { { author = { login = "b" }, body = "y", createdAt = "2026-01-02T00:00:00Z" } } },
        },
      })

      assert.are.equal(2, #grouped)
      assert.are.equal("src/a.lua", grouped[1].file)
      assert.are.equal("src/b.lua", grouped[2].file)
    end)

    it("keeps multiple threads for the same file in one group, input order preserved", function()
      local grouped = parse.group_by_file({
        {
          isResolved = false,
          path = "src/a.lua",
          line = 1,
          comments = { nodes = { { author = { login = "a" }, body = "first", createdAt = "2026-01-01T00:00:00Z" } } },
        },
        {
          isResolved = false,
          path = "src/a.lua",
          line = 10,
          comments = { nodes = { { author = { login = "b" }, body = "second", createdAt = "2026-01-02T00:00:00Z" } } },
        },
      })

      assert.are.equal(1, #grouped)
      assert.are.equal(2, #grouped[1].threads)
      assert.are.equal("first", grouped[1].threads[1].comments[1].body)
      assert.are.equal("second", grouped[1].threads[2].comments[1].body)
    end)

    it("normalizes resolved and comment fields", function()
      local grouped = parse.group_by_file({
        {
          isResolved = true,
          path = "src/a.lua",
          line = 3,
          comments = {
            nodes = {
              { author = { login = "reviewer" }, body = "please fix", createdAt = "2026-01-01T00:00:00Z" },
            },
          },
        },
      })

      local thread = grouped[1].threads[1]
      assert.is_true(thread.resolved)
      assert.are.equal("src/a.lua", thread.file)
      assert.are.equal(3, thread.line)
      assert.are.equal("reviewer", thread.comments[1].author)
      assert.are.equal("please fix", thread.comments[1].body)
      assert.are.equal("2026-01-01T00:00:00Z", thread.comments[1].created_at)
    end)

    it("falls back to originalLine when line is nil (outdated/resolved thread)", function()
      local grouped = parse.group_by_file({
        {
          isResolved = true,
          path = "src/a.lua",
          line = vim.NIL,
          originalLine = 7,
          comments = { nodes = { { author = { login = "a" }, body = "x", createdAt = "2026-01-01T00:00:00Z" } } },
        },
      })

      assert.are.equal(7, grouped[1].threads[1].line)
    end)

    it("returns an empty list for an empty input", function()
      assert.are.same({}, parse.group_by_file({}))
    end)
  end)
end)
