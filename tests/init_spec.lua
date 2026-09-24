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
      local loading_opened, view_opened_with, view_opened_with_root

      package.loaded["the-grapevine.gh"] = {
        find_pr = function(callback)
          callback({ owner = "o", repo = "r", number = 1, url = "u", root = "/some/repo" }, nil)
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
        open = function(grouped, root)
          view_opened_with = grouped
          view_opened_with_root = root
        end,
      }

      grapevine = require("the-grapevine")
      grapevine.open()

      assert.is_true(loading_opened)
      assert.is_not_nil(view_opened_with)
      assert.are.equal(1, #view_opened_with)
      assert.are.equal("src/a.lua", view_opened_with[1].file)
      assert.are.equal("/some/repo", view_opened_with_root)
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

  describe("open when gh is not installed", function()
    local original_executable

    before_each(function()
      original_executable = vim.fn.executable
    end)

    after_each(function()
      vim.fn.executable = original_executable
    end)

    it("notifies and never reaches find_pr or view.open_loading", function()
      vim.fn.executable = function(name)
        if name == "gh" then
          return 0
        end
        return original_executable(name)
      end

      local opened = false
      local find_pr_called = false
      package.loaded["the-grapevine.gh"] = {
        find_pr = function(callback)
          find_pr_called = true
          callback(nil, "should not be called")
        end,
        fetch_threads = function(_pr, callback)
          callback(nil, "should not be called")
        end,
      }
      package.loaded["the-grapevine.view"] = {
        open_loading = function()
          opened = true
        end,
        close = function() end,
        open = function() end,
      }

      grapevine = require("the-grapevine")
      grapevine.open()

      assert.is_false(opened, "view.open_loading must not be called when gh is missing")
      assert.is_false(find_pr_called, "gh.find_pr must not be called when gh is missing")
      assert.are.equal(1, #notified)
      assert.are.equal(vim.log.levels.ERROR, notified[1].level)
      assert.is_true(notified[1].msg:find("'gh' CLI is not installed") ~= nil)
    end)
  end)
end)
