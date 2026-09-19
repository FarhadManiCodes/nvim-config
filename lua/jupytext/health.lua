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
-- resolver would actually pick, since that -- not merely "is it on PATH" -- is
-- what decides whether notebooks open as markdown.
--
-- The candidate list comes from config/jupytext_resolve.lua, the same module the
-- spec in lua/plugins/jupytext.lua resolves through. It used to be a copy, on the
-- grounds that a healthcheck importing what it checks proves only that the import
-- worked. That holds for importing the plugin; it does not hold for a list of
-- paths, and the copy carried a worse risk -- a changed order in the spec would
-- have left this reporting the intended pick rather than the real one, with
-- nothing to notice. What is checked is still checked HERE: the executable() test
-- and the --version call below are this file's own.

local M = {}

M.check = function()
  vim.health.start("jupytext.nvim (local healthcheck)")

  local list = require("config.jupytext_resolve").candidates()
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
        "Install it in the project venv, then `:restart`:",
        "  uv pip install jupytext         # the normal route here",
        "  uv tool install jupytext        # or everywhere, if you prefer",
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
      .. "notebooks when the CLI is missing. See lua/plugins/jupytext.lua."
  )
end

return M
