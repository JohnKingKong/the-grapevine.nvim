-- tests/integration_spec.lua
-- Every other spec stubs one side of the parse -> view seam (parse_spec
-- feeds hand-built raw threads straight into assertions; view_spec feeds
-- hand-built "grouped" fixtures straight into render). Neither proves the
-- real shape parse.group_by_file emits is the shape view.render expects.
-- This test runs a realistic raw GraphQL-shaped payload through both real
-- functions back to back.
describe("the-grapevine parse -> view integration", function()
  before_each(function()
    package.loaded["the-grapevine.parse"] = nil
    package.loaded["the-grapevine.view"] = nil
  end)

  it("group_by_file's output renders correctly through the real view.render", function()
    local parse = require("the-grapevine.parse")
    local view = require("the-grapevine.view")

    local raw_threads = {
      {
        isResolved = false,
        path = "src/foo.lua",
        line = 12,
        originalLine = 12,
        comments = {
          nodes = {
            {
              author = { login = "reviewer1" },
              body = "why is this here?",
              createdAt = "2026-01-01T00:00:00Z",
            },
          },
        },
      },
      {
        isResolved = true,
        path = "src/bar.lua",
        line = vim.NIL,
        originalLine = 3,
        comments = {
          nodes = {
            {
              author = { login = "reviewer2" },
              body = "please fix this typo",
              createdAt = "2026-01-02T00:00:00Z",
            },
          },
        },
      },
    }

    local grouped = parse.group_by_file(raw_threads)
    local lines = view.render(grouped, true)
    local joined = table.concat(lines, "\n")

    -- plain=true: "why is this here?" contains "?", a Lua pattern special
    -- character, per the convention established in view_spec.lua.
    assert.is_true(joined:find("src/foo%.lua") ~= nil)
    assert.is_true(joined:find("src/bar%.lua") ~= nil)
    assert.is_true(joined:find("reviewer1") ~= nil)
    assert.is_true(joined:find("reviewer2") ~= nil)
    assert.is_true(joined:find("why is this here?", 1, true) ~= nil)
    assert.is_true(joined:find("please fix this typo", 1, true) ~= nil)
  end)
end)
