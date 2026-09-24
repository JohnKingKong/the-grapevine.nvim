# the-grapevine.nvim

Read-only viewer for GitHub PR review comments — resolved and
unresolved — for the current branch's open PR, grouped by file, jump
straight to the code.

## Why

octo.nvim already does this, but its review mode wants a full review
session with a diff layout just to read what people said. This is just
a fast, clean view of the comments.

## Installation (lazy.nvim)

```lua
return {
  "johnkingkong/the-grapevine.nvim",
  cmd = "Grapevine",
  keys = {
    { "<leader>gv", "<cmd>Grapevine<cr>", desc = "PR review comments" },
  },
}
```

Requires the [`gh` CLI](https://cli.github.com/), authenticated
(`gh auth login`) with at least `repo` scope.

## Usage

Run `:Grapevine` from a branch with an open PR. Comments are grouped by
file; resolved threads are hidden by default.

| Key | Action |
|---|---|
| `<CR>` | Jump to the file/line the comment under the cursor refers to |
| `R` | Toggle resolved threads visible/hidden |
| `q` / `<Esc>` | Close |

## Scope

Read-only for now — no replying or resolving from within Neovim.

## License

MIT
