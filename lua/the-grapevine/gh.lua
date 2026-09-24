local M = {}

local function run(cmd, callback)
  vim.system(cmd, { text = true }, callback)
end

function M.find_pr(callback)
  run({ "gh", "repo", "view", "--json", "owner,name" }, function(repo_result)
    if repo_result.code ~= 0 then
      callback(nil, "gh repo view failed: " .. (repo_result.stderr or ""))
      return
    end
    local ok, repo_data = pcall(vim.json.decode, repo_result.stdout)
    if not ok or type(repo_data) ~= "table" or type(repo_data.owner) ~= "table" or not repo_data.owner.login or not repo_data.name then
      callback(nil, "gh repo view returned unexpected output")
      return
    end
    local owner, repo = repo_data.owner.login, repo_data.name

    run({ "gh", "pr", "view", "--json", "number,state,url" }, function(pr_result)
      if pr_result.code ~= 0 then
        callback(nil, "No open PR found for the current branch: " .. (pr_result.stderr or ""))
        return
      end
      local ok2, pr_data = pcall(vim.json.decode, pr_result.stdout)
      if not ok2 or type(pr_data) ~= "table" or not pr_data.number then
        callback(nil, "gh pr view returned unexpected output")
        return
      end
      callback({ owner = owner, repo = repo, number = pr_data.number, url = pr_data.url }, nil)
    end)
  end)
end

return M
