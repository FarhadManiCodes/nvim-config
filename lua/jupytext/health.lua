-- Replacement healthcheck for jupytext.nvim.
--
-- Why this file exists: the plugin's own lua/jupytext/health.lua calls
-- vim.health.report_start, which Neovim REMOVED in 0.10 (renamed to
-- vim.health.start). So `:checkhealth` did not merely report a problem, it threw:
--
--   ERROR Failed to run healthcheck for "jupytext" plugin. Exception:
--   .../jupytext/health.lua:4: attempt to call field 'report_start' (a nil value)
--
-- ~/.config/nvim precedes the lazy plugin directories on the runtimepath, so a
-- module of the same name here shadows the plugin's without touching it -- which
-- matters because an edit under ~/.local/share/nvim/lazy is reverted by the next
-- plugin update and is not tracked anywhere.
--
-- Only health.lua is shadowed. `require("jupytext")` still resolves to the
-- plugin, because Lua looks for lua/jupytext.lua or lua/jupytext/init.lua and
-- this directory has neither (verified).
--
-- It also reports something upstream's could not: which jupytext the venv-first
-- resolver in lua/plugins/init.lua would actually pick, since that -- not merely
-- "is it on PATH" -- is what decides whether notebooks open as markdown.

local M = {}

-- Mirrors the resolution order in the jupytext spec in lua/plugins/init.lua.
-- Kept as a copy rather than shared: a healthcheck that imports the thing it is
-- checking reports success whenever the import works, which is not the question.
local function candidates()
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

M.check = function()
  vim.health.start("jupytext.nvim (local healthcheck)")

  local list = candidates()
  local chosen
  for _, c in ipairs(list) do
    if vim.fn.executable(c.path) == 1 then
      chosen = c
      break
    end
  end

  if chosen then
    local ver = vim.fn.system({ chosen.path, "--version" }):gsub("%s+$", "")
    vim.health.ok(string.format("jupytext found via %s: %s (%s)", chosen.src, chosen.path, ver))
    vim.health.ok("`.ipynb` files will open as markdown")
  else
    -- Not an error: declining to arm is the designed, safe outcome. Reporting it
    -- as an error would train you to ignore this section.
    vim.health.warn(
      "no jupytext found -- `.ipynb` will open as raw JSON (safe fallback, not a failure)",
      {
        "Install it where the project can see it, then `:restart`:",
        "  uv tool install jupytext        # available everywhere",
        "  uv pip install jupytext         # just this venv",
        "Looked in: $VIRTUAL_ENV/bin, <root>/.venv/bin, PATH",
      }
    )
  end

  if #list == 0 then
    vim.health.info("no candidate locations at all (no $VIRTUAL_ENV, no project root)")
  end

  -- The guard is the whole reason eager loading is safe; say so where someone
  -- debugging notebooks will actually look.
  vim.health.info(
    "Resolution is venv-first and setup() only runs when a binary exists; "
      .. "without one the plugin is never armed, because its read path truncates "
      .. "notebooks when the CLI is missing. See lua/plugins/init.lua."
  )
end

return M
