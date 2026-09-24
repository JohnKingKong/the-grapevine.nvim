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

      assert.is_nil(pr)
      assert.is_not_nil(err)
    end)
  end)
end)
