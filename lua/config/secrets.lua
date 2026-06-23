-- ~/.config/nvim/lua/config/secrets.lua
-- Load API keys from ~/.config/secrets/*.env into THIS Neovim process's env.
--
-- Why Lua instead of sourcing in zsh:
--   * nvim has the value regardless of how it was launched (terminal, file
--     manager, systemd, a non-interactive shell) — env inheritance is not relied on.
--   * the secret lives only in this process (+ the 600 file), not exported into
--     every interactive shell and inherited by every child process.
-- Files live under ~/.config/secrets/ (chmod 600, never tracked in git).
-- Consumers read them normally via os.getenv (e.g. minuet's api_key = "NAME").

local M = {}

local SECRETS_DIR = vim.fn.expand("~/.config/secrets")

-- Parse a `KEY=VALUE` / `export KEY=VALUE` file and set vim.env (→ os.getenv).
-- Skips blank lines, comments, and empty values (so a placeholder file is a no-op).
-- Strips one layer of matching surrounding quotes. Returns count of keys set.
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
        vim.env[key] = val
        n = n + 1
      end
    end
  end
  fd:close()
  return n
end

return M
