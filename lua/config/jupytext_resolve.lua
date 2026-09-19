-- ~/.config/nvim/lua/config/jupytext_resolve.lua
-- Where to look for the `jupytext` CLI, in order.
--
-- One definition with two consumers: the spec in lua/plugins/jupytext.lua, which
-- resolves per notebook open and only arms the plugin when something is found,
-- and lua/jupytext/health.lua, which reports which one :checkhealth would pick.
-- They used to carry a copy each. Nothing compared them, so a change to the
-- order in the spec would have left the healthcheck confidently naming a binary
-- that was never used -- a probe reporting the intended answer rather than the
-- actual one. Health still runs its own executable() and --version probes; only
-- the candidate list comes from here.
--
-- Venv-first ordering: $VIRTUAL_ENV (direnv or `va` activated something) beats a
-- project-local .venv, which beats PATH (a uv tool install). Jupyter lives in
-- per-project venvs here, never system-wide, so the project's own copy is the
-- one that matches the notebook's kernel.

local M = {}

-- Ordered candidate list, each entry labelled with where it came from. The
-- labels are for the healthcheck; resolve() ignores them.
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

-- First candidate that actually exists, or nil. Nil is a supported answer, not
-- an error: it is what keeps the plugin unarmed -- see lua/plugins/jupytext.lua.
function M.resolve()
  for _, c in ipairs(M.candidates()) do
    if vim.fn.executable(c.path) == 1 then
      return c.path
    end
  end
end

return M
