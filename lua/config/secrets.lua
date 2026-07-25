-- ~/.config/nvim/lua/config/secrets.lua
-- Load API keys from ~/.config/secrets/*.env for use by THIS Neovim process.
--
-- Why Lua instead of sourcing in zsh:
--   * nvim has the value regardless of how it was launched (terminal, file
--     manager, systemd, a non-interactive shell) — env inheritance is not relied on.
--   * the secret is not exported into every interactive shell, so unrelated
--     terminals and their children never carry it.
--
-- Two ways to consume a loaded key:
--
--   M.get(name)   — preferred. Returns the value from an in-process table. The
--                   secret exists only in this Lua state: it is NOT in the
--                   process environment, so none of the programs nvim spawns
--                   (LSP servers, :terminal shells, :! commands, jobstart) can
--                   read it. Use this whenever the consumer accepts a function,
--                   as minuet's `api_key` does (utils.get_api_key calls it).
--
--   M.export(name)— opt-in escape hatch that additionally sets vim.env, for a
--                   consumer that can ONLY read a real environment variable.
--                   Be aware this hands the value to every child process nvim
--                   spawns, since children inherit the environment wholesale.
--
-- Files live under ~/.config/secrets/ (chmod 600, never tracked in git).

local M = {}

local SECRETS_DIR = vim.fn.expand("~/.config/secrets")

-- Loaded key/value pairs, in-process only. Never written to vim.env by load().
local store = {}

-- Parse a `KEY=VALUE` / `export KEY=VALUE` file into the in-process store.
-- Skips blank lines, comments, and empty values (so a placeholder file is a no-op).
-- Strips one layer of matching surrounding quotes. Returns count of keys loaded.
function M.load(file)
  local fd = io.open(SECRETS_DIR .. "/" .. file, "r")
  if not fd then
    return 0
  end
  local n = 0
  for line in fd:lines() do
    local key, val = line:match("^%s*export%s+([%w_]+)%s*=%s*(.*)$")
    if not key then
      key, val = line:match("^%s*([%w_]+)%s*=%s*(.*)$")
    end
    if key and val then
      val = val:gsub("%s+$", ""):gsub('^(["\'])(.*)%1$', "%2")
      if val ~= "" then
        store[key] = val
        n = n + 1
      end
    end
  end
  fd:close()
  return n
end

-- Read a loaded secret. Falls back to the real environment so a key exported
-- by other means still resolves. Returns nil if unset.
function M.get(name)
  return store[name] or vim.env[name]
end

-- Publish a loaded secret into vim.env. Only for consumers that cannot take a
-- function/value. See the caveat in the header: every child process inherits it.
function M.export(name)
  local val = M.get(name)
  if val then
    vim.env[name] = val
  end
  return val
end

return M
