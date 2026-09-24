-- tests/gh_spec.lua
describe("the-grapevine.gh", function()
  local gh
  local original_system

  before_each(function()
    package.loaded["the-grapevine.gh"] = nil
    gh = require("the-grapevine.gh")
    original_system = vim.system
  end)

  after_each(function()
    vim.system = original_system
  end)

  describe("find_pr", function()
    it("combines gh repo view and gh pr view into one result on success", function()
      vim.system = function(cmd, _opts, callback)
        if cmd[1] == "gh" and cmd[2] == "repo" and cmd[3] == "view" then
          callback({
            code = 0,
            stdout = '{"name":"clickaholic.nvim","owner":{"id":"x","login":"JohnKingKong"}}',
            stderr = "",
          })
        elseif cmd[1] == "gh" and cmd[2] == "pr" and cmd[3] == "view" then
          callback({
            code = 0,
            stdout = '{"number":42,"state":"OPEN","url":"https://github.com/JohnKingKong/clickaholic.nvim/pull/42"}',
            stderr = "",
          })
        else
          error("unexpected command: " .. table.concat(cmd, " "))
        end
      end

      local pr, err
      gh.find_pr(function(result_pr, result_err)
        pr, err = result_pr, result_err
      end)
      vim.wait(100, function()
        return pr ~= nil or err ~= nil
      end)

      assert.is_nil(err)
      assert.are.same({
        owner = "JohnKingKong",
        repo = "clickaholic.nvim",
        number = 42,
        url = "https://github.com/JohnKingKong/clickaholic.nvim/pull/42",
      }, pr)
    end)

    it("reports an error when gh repo view fails", function()
      vim.system = function(_cmd, _opts, callback)
        callback({ code = 1, stdout = "", stderr = "not a git repository" })
      end

      local pr, err
      gh.find_pr(function(result_pr, result_err)
        pr, err = result_pr, result_err
      end)
      vim.wait(100, function()
        return pr ~= nil or err ~= nil
      end)

      assert.is_nil(pr)
      assert.is_true(err:find("not a git repository") ~= nil)
    end)

    it("reports 'no open PR' when gh pr view fails", function()
      vim.system = function(cmd, _opts, callback)
        if cmd[3] == "view" and cmd[2] == "repo" then
          callback({ code = 0, stdout = '{"name":"x","owner":{"id":"y","login":"z"}}', stderr = "" })
        else
          callback({ code = 1, stdout = "", stderr = 'no pull requests found for branch "main"\n' })
        end
      end

      local pr, err
      gh.find_pr(function(result_pr, result_err)
        pr, err = result_pr, result_err
      end)
      vim.wait(100, function()
        return pr ~= nil or err ~= nil
      end)

      assert.is_nil(pr)
      assert.is_true(err:find("No open PR") ~= nil)
    end)

    it("reports an error on malformed JSON from gh repo view", function()
      vim.system = function(_cmd, _opts, callback)
        callback({ code = 0, stdout = "not json", stderr = "" })
      end

      local pr, err
      gh.find_pr(function(result_pr, result_err)
        pr, err = result_pr, result_err
      end)
      vim.wait(100, function()
        return pr ~= nil or err ~= nil
      end)

      assert.is_nil(pr)
      assert.is_not_nil(err)
    end)
  end)

  describe("fetch_threads", function()
    it("returns the raw reviewThreads.nodes array on success", function()
      local response = vim.json.encode({
        data = {
          repository = {
            pullRequest = {
              reviewThreads = {
                nodes = {
                  {
                    isResolved = false,
                    path = "src/foo.lua",
                    line = 42,
                    originalLine = 42,
                    comments = {
                      nodes = {
                        { author = { login = "reviewer1" }, body = "why?", createdAt = "2026-01-01T00:00:00Z" },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      })
      vim.system = function(cmd, _opts, callback)
        assert.are.equal("gh", cmd[1])
        assert.are.equal("api", cmd[2])
        assert.are.equal("graphql", cmd[3])
        callback({ code = 0, stdout = response, stderr = "" })
      end

      local threads, err
      gh.fetch_threads({ owner = "o", repo = "r", number = 1, url = "u" }, function(result_threads, result_err)
        threads, err = result_threads, result_err
      end)
      vim.wait(100, function()
        return threads ~= nil or err ~= nil
      end)

      assert.is_nil(err)
      assert.are.equal(1, #threads)
      assert.are.equal("src/foo.lua", threads[1].path)
      assert.are.equal(false, threads[1].isResolved)
    end)

    it("returns an empty array when the PR has no review threads", function()
      local response = vim.json.encode({
        data = { repository = { pullRequest = { reviewThreads = { nodes = {} } } } },
      })
      vim.system = function(_cmd, _opts, callback)
        callback({ code = 0, stdout = response, stderr = "" })
      end

      local threads, err
      gh.fetch_threads({ owner = "o", repo = "r", number = 1, url = "u" }, function(result_threads, result_err)
        threads, err = result_threads, result_err
      end)
      vim.wait(100, function()
        return threads ~= nil or err ~= nil
      end)

      assert.is_nil(err)
      assert.are.same({}, threads)
    end)

    it("reports an error when gh api graphql fails", function()
      vim.system = function(_cmd, _opts, callback)
        callback({ code = 1, stdout = "", stderr = "GraphQL error: bad credentials" })
      end

      local threads, err
      gh.fetch_threads({ owner = "o", repo = "r", number = 1, url = "u" }, function(result_threads, result_err)
        threads, err = result_threads, result_err
      end)
      vim.wait(100, function()
        return threads ~= nil or err ~= nil
      end)

      assert.is_nil(threads)
      assert.is_true(err:find("bad credentials") ~= nil)
    end)

    it("reports an error on malformed JSON", function()
      vim.system = function(_cmd, _opts, callback)
        callback({ code = 0, stdout = "not json", stderr = "" })
      end

      local threads, err
      gh.fetch_threads({ owner = "o", repo = "r", number = 1, url = "u" }, function(result_threads, result_err)
        threads, err = result_threads, result_err
      end)
      vim.wait(100, function()
        return threads ~= nil or err ~= nil
      end)

      assert.is_nil(threads)
      assert.is_not_nil(err)
    end)
  end)
end)
