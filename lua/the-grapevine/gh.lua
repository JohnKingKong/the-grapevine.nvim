-- lua/the-grapevine/gh.lua
local M = {}

local function run(cmd, callback)
  vim.system(cmd, { text = true }, vim.schedule_wrap(callback))
end

function M.find_pr(callback)
  run({ "gh", "repo", "view", "--json", "owner,name" }, function(repo_result)
    if repo_result.code ~= 0 then
      callback(nil, "gh repo view failed: " .. (repo_result.stderr or ""))
      return
    end
    local ok, repo_data = pcall(vim.json.decode, repo_result.stdout)
    if
      not ok
      or type(repo_data) ~= "table"
      or type(repo_data.owner) ~= "table"
      or not repo_data.owner.login
      or not repo_data.name
    then
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

local REVIEW_THREADS_QUERY = [[
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        nodes {
          isResolved
          path
          line
          originalLine
          comments(first: 50) {
            nodes {
              author { login }
              body
              createdAt
            }
          }
        }
      }
    }
  }
}
]]

function M.fetch_threads(pr, callback)
  run({
    "gh",
    "api",
    "graphql",
    "-f",
    "query=" .. REVIEW_THREADS_QUERY,
    "-F",
    "owner=" .. pr.owner,
    "-F",
    "repo=" .. pr.repo,
    "-F",
    "number=" .. pr.number,
  }, function(result)
    if result.code ~= 0 then
      callback(nil, "gh api graphql failed: " .. (result.stderr or ""))
      return
    end
    local ok, decoded = pcall(vim.json.decode, result.stdout)
    if
      not ok
      or type(decoded) ~= "table"
      or type(decoded.data) ~= "table"
      or type(decoded.data.repository) ~= "table"
      or type(decoded.data.repository.pullRequest) ~= "table"
      or type(decoded.data.repository.pullRequest.reviewThreads) ~= "table"
    then
      callback(nil, "gh api graphql returned unexpected output")
      return
    end
    callback(decoded.data.repository.pullRequest.reviewThreads.nodes or {}, nil)
  end)
end

return M
