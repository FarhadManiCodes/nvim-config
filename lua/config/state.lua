-- ~/.config/nvim/lua/config/state.lua
-- Tiny single-line persisted state under stdpath("data").
--
-- Four call sites were each hand-rolling the same stdpath + io.open + read("*l")
-- + close dance to remember one value between sessions (last theme, which-key
-- enabled, the Neovim version treesitter last synced against). None of it is
-- hard, but having it in one place means the nil-handling and the close() are
-- right once rather than four times.
--
-- Deliberately minimal: one line per file, no serialization, no caching. These
-- are preferences that change at most a few times a session, so the file is
-- read on demand rather than held in memory where it could go stale against
-- another running Neovim instance.

local M = {}

local function path(name)
  return vim.fn.stdpath("data") .. "/" .. name
end

--- Read the first line of a state file.
--- @param name string filename under stdpath("data")
--- @return string|nil value, or nil when the file is absent or empty
function M.read(name)
  local f = io.open(path(name), "r")
  if not f then
    return nil
  end
  local value = f:read("*l")
  f:close()
  return value
end

--- Write a single-line value to a state file. Silently no-ops when the file
--- cannot be opened (read-only data dir) — persistence is a convenience here,
--- never something a caller must handle failing.
--- @param name string filename under stdpath("data")
--- @param value any tostring()-ed before writing
--- @return boolean written
function M.write(name, value)
  local f = io.open(path(name), "w")
  if not f then
    return false
  end
  f:write(tostring(value))
  f:close()
  return true
end

return M
