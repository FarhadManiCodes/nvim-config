-- Run from the repository root:
-- nvim --headless -u NONE -i NONE -l tests/treesitter.lua
-- Real parsers/ftplugins and production setup, without installing/updating plugins.
-- Also usable through :lua dofile(...) with the full config. Keep LSP servers
-- away from these anonymous synthetic buffers; they are not LSP fixtures.
vim.lsp.enable({ "lua_ls", "ruff", "basedpyright" }, false)
vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/lazy/nvim-treesitter")
vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/site")
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.cmd("filetype plugin on")
vim.o.hidden = true
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
local ts = require("nvim-treesitter")
ts.install = function() end
dofile("lua/plugins/treesitter.lua")[1].config()
local count = 0
local function check(value, message)
  assert(value, message)
  count = count + 1
end
local function settle()
  -- Drain scheduled buffer updates before checking their effects.
  local done = false
  vim.schedule(function() done = true end)
  assert(vim.wait(5000, function() return done end, 1))
end
local function highlight(buf)
  return vim.treesitter.highlighter.active[buf] ~= nil
end
local function new(lines, visible)
  local buf = vim.api.nvim_create_buf(true, false)
  if visible then vim.api.nvim_win_set_buf(0, buf) end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("filetype", "lua", { buf = buf })
  settle()
  return buf
end
local small = { "local function f()", "  return 1", "end" }
local large = { "--" .. string.rep("x", 1024 * 1024) }
local b = new(small, true)
check(highlight(b), "small buffer highlights")
check(vim.wo.foldmethod == "expr", "small buffer folds")
local parser = vim.treesitter.get_parser(b)
local captures = 0
for _ in vim.treesitter.query.get("lua", "highlights"):iter_captures(parser:parse()[1]:root(), b) do
  captures = captures + 1
end
check(captures > 0, "small buffer has actual highlight captures")

-- Unsaved growth, including hidden-buffer API edits and multiple windows/tabs.
vim.cmd("split")
local first, second = vim.api.nvim_list_wins()[1], vim.api.nvim_list_wins()[2]
vim.cmd("tab split")
local third = vim.api.nvim_get_current_win()
vim.api.nvim_buf_set_lines(b, 0, -1, false, large)
settle()
check(not highlight(b), "unsaved growth stops highlighting")
for _, win in ipairs({ first, second, third }) do
  check(vim.wo[win].foldmethod == "manual", "growth guards every window/tab")
end
vim.api.nvim_buf_set_lines(b, 0, -1, false, small)
settle()
check(highlight(b), "shrinking restarts highlighting")
for _, win in ipairs({ first, second, third }) do
  check(vim.wo[win].foldmethod == "expr", "shrinking restores each window")
end
vim.cmd("tabclose")
vim.cmd("only")

local hidden = new(large, false)
check(not highlight(hidden), "hidden large buffer stops highlighting")
vim.api.nvim_win_set_buf(0, hidden)
check(vim.wo.foldmethod == "manual", "hidden large buffer guarded on display")
vim.cmd("vsplit")
check(vim.wo.foldmethod == "manual", "new split of large buffer guarded")
vim.cmd("only")
local next_small = new(small, true)
check(vim.wo.foldmethod == "expr", "large-buffer fold setting does not leak")
vim.api.nvim_buf_set_lines(hidden, 0, -1, false, small)
settle()
check(highlight(hidden), "hidden shrink resumes highlighting")
vim.api.nvim_win_set_buf(0, hidden)
check(vim.wo.foldmethod == "expr", "hidden shrink restores folding on display")

-- Exact boundary uses Neovim's byte count, including its final newline.
vim.api.nvim_buf_set_lines(hidden, 0, -1, false, { "--" .. string.rep("x", 1024 * 1024 - 3) })
settle()
check(highlight(hidden), "exactly 1 MiB remains enabled")
vim.api.nvim_buf_set_text(hidden, 0, 2, 0, 2, { "x" })
settle()
check(not highlight(hidden), "one byte over 1 MiB is disabled")
vim.api.nvim_buf_set_lines(hidden, 0, -1, false, small)
settle()

-- Respect the separate >10 MiB policy even if the buffer later shrinks.
vim.b[hidden].large_file = true
vim.api.nvim_exec_autocmds("FileType", { buffer = hidden })
check(not highlight(hidden) and vim.wo.foldmethod == "manual", "large_file flag wins")
vim.b[hidden].large_file = nil
vim.api.nvim_exec_autocmds("FileType", { buffer = hidden })
check(highlight(hidden) and vim.wo.foldmethod == "expr", "clearing flag restores policy")

vim.wo[0][0].foldmethod = "marker"
vim.api.nvim_buf_set_lines(hidden, 0, -1, false, large)
settle()
vim.api.nvim_buf_set_lines(hidden, 0, -1, false, small)
settle()
check(vim.wo.foldmethod == "marker", "preserve pre-existing fold method")
vim.api.nvim_set_option_value("filetype", "python", { buf = hidden })
check(vim.treesitter.highlighter.active[hidden].tree:lang() == "python", "filetype change switches parser")

-- Preserve an explicit fold-method change made while the guard is active.
vim.api.nvim_buf_set_lines(hidden, 0, -1, false, large)
settle()
vim.wo[0][0].foldmethod = "marker"
vim.api.nvim_buf_set_lines(hidden, 0, -1, false, small)
settle()
check(vim.wo.foldmethod == "marker", "shrinking preserves user's intervening fold choice")

-- File reads/reloads, with unchanged filetype: a FileType-only guard misses these.
local path = vim.fn.tempname() .. ".lua"
vim.fn.writefile(large, path)
vim.cmd.edit(path)
settle()
check(not highlight(vim.api.nvim_get_current_buf()), "large disk file is guarded")
vim.fn.writefile(small, path)
vim.cmd("edit!")
settle()
check(highlight(vim.api.nvim_get_current_buf()), "reload of smaller file resumes")
vim.fn.writefile(large, path)
vim.cmd("edit!")
settle()
check(not highlight(vim.api.nvim_get_current_buf()), "reload of larger file stops")
vim.fn.delete(path)

-- The full config also has a >10 MiB BufReadPre policy. Verify its window
-- options compose with this guard, including the next unrelated buffer.
local huge_path = vim.fn.tempname() .. ".lua"
vim.fn.writefile({ "--" .. string.rep("x", 10 * 1024 * 1024) }, huge_path)
vim.cmd.edit(huge_path)
settle()
check(not highlight(vim.api.nvim_get_current_buf()) and vim.wo.foldmethod == "manual",
  "file above 10 MiB is guarded")
new(small, true)
check(vim.wo.foldmethod == "expr", "10 MiB policy does not leak into a new buffer")
vim.fn.delete(huge_path)

vim.api.nvim_win_set_buf(0, next_small)
vim.api.nvim_buf_set_lines(hidden, 0, -1, false, large)
vim.api.nvim_buf_delete(hidden, { force = true })
settle()
check(vim.wo.foldmethod == "expr", "pending callback after wipeout is safe")
print("PASS: " .. count .. " treesitter guard assertions")
vim.cmd("qa!")
