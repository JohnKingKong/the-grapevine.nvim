-- tests/init_spec.lua
describe("the-grapevine.init", function()
  local grapevine
  local notified

  before_each(function()
    package.loaded["the-grapevine"] = nil
    package.loaded["the-grapevine.gh"] = nil
    package.loaded["the-grapevine.view"] = nil
    notified = {}
    vim.notify = function(msg, level)
      table.insert(notified, { msg = msg, level = level })
    end
  end)

  describe("open", function()
    it("finds the PR, fetches threads, groups them, and opens the view on success", function()
      local loading_opened, view_opened_with

      package.loaded["the-grapevine.gh"] = {
        find_pr = function(callback)
          callback({ owner = "o", repo = "r", number = 1, url = "u" }, nil)
        end,
        fetch_threads = function(_pr, callback)
          callback({
            {
              isResolved = false,
              path = "src/a.lua",
              line = 1,
              comments = { nodes = { { author = { login = "x" }, body = "hi", createdAt = "2026-01-01T00:00:00Z" } } },
            },
          }, nil)
        end,
      }
      package.loaded["the-grapevine.view"] = {
        open_loading = function()
          loading_opened = true
        end,
        open = function(grouped)
          view_opened_with = grouped
        end,
      }

      grapevine = require("the-grapevine")
      grapevine.open()

      assert.is_true(loading_opened)
      assert.is_not_nil(view_opened_with)
      assert.are.equal(1, #view_opened_with)
      assert.are.equal("src/a.lua", view_opened_with[1].file)
      assert.are.equal(0, #notified, "no error notification on the happy path")
    end)

    it("notifies and does not call view.open when find_pr fails", function()
      local view_open_called = false
      local view_close_called = false
      package.loaded["the-grapevine.gh"] = {
        find_pr = function(callback)
          callback(nil, "No open PR found for the current branch")
        end,
        fetch_threads = function(_pr, callback)
          callback(nil, "should not be called")
        end,
      }
      package.loaded["the-grapevine.view"] = {
        open_loading = function() end,
        close = function()
          view_close_called = true
        end,
        open = function()
          view_open_called = true
        end,
      }

      grapevine = require("the-grapevine")
      grapevine.open()

      assert.is_false(view_open_called)
      assert.is_true(view_close_called)
      assert.are.equal(1, #notified)
      assert.are.equal(vim.log.levels.ERROR, notified[1].level)
      assert.is_true(notified[1].msg:find("No open PR") ~= nil)
    end)

    it("notifies and does not call view.open when fetch_threads fails", function()
      local view_open_called = false
      local view_close_called = false
      package.loaded["the-grapevine.gh"] = {
        find_pr = function(callback)
          callback({ owner = "o", repo = "r", number = 1, url = "u" }, nil)
        end,
        fetch_threads = function(_pr, callback)
          callback(nil, "gh api graphql failed: bad credentials")
        end,
      }
      package.loaded["the-grapevine.view"] = {
        open_loading = function() end,
        close = function()
          view_close_called = true
        end,
        open = function()
          view_open_called = true
        end,
      }

      grapevine = require("the-grapevine")
      grapevine.open()

      assert.is_false(view_open_called)
      assert.is_true(view_close_called)
      assert.are.equal(1, #notified)
      assert.are.equal(vim.log.levels.ERROR, notified[1].level)
      assert.is_true(notified[1].msg:find("bad credentials") ~= nil)
    end)
  end)
end)
