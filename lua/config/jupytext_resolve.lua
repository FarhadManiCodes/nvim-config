-- ~/.config/nvim/lua/config/jupytext_resolve.lua
-- Shared lookup order for notebook reads and the healthcheck:
-- $VIRTUAL_ENV → project .venv → PATH. Recomputed on each call so environments
-- activated after startup are picked up on the next notebook read.

local M = {}

-- Source labels let the healthcheck explain its choice.
function M.candidates()
  local out = {}
  if vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV ~= "" then
    out[#out + 1] = { src = "$VIRTUAL_ENV", path = vim.env.VIRTUAL_ENV .. "/bin/jupytext" }
  end
  local root = vim.fs.root(vim.uv.cwd(), { ".venv", "pyproject.toml", ".git" })
  if root then
    out[#out + 1] = { src = "<root>/.venv", path = root .. "/.venv/bin/jupytext" }
  end
  local onpath = vim.fn.exepath("jupytext")
  if onpath ~= "" then
    out[#out + 1] = { src = "PATH", path = onpath }
  end
  return out
end

-- First executable, or nil to make the read wrapper fall back to raw JSON.
function M.resolve()
  for _, c in ipairs(M.candidates()) do
    if vim.fn.executable(c.path) == 1 then
      return c.path
    end
  end
end

return M
