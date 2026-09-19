-- Shadows upstream's healthcheck, which calls the removed vim.health.report_start.
-- This config precedes plugins on runtimepath; no jupytext.lua or jupytext/init.lua
-- exists here, so require("jupytext") still loads the plugin itself.
-- Candidate ordering is shared with notebook reads; executable/version probes
-- run here without loading or configuring the plugin. See docs/architecture.md.

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
    -- Missing conversion support uses the safe raw-JSON fallback.
    vim.health.warn(
      "no jupytext found -- `.ipynb` will open as raw JSON (safe fallback, not a failure)",
      {
        "Install it in the project venv, then reopen the notebook (no restart needed):",
        "  uv pip install jupytext         # the normal route here",
        "  uv tool install jupytext        # or everywhere, if you prefer",
        "Looked in: $VIRTUAL_ENV/bin, <root>/.venv/bin, PATH",
      }
    )
  end

  if #list == 0 then
    vim.health.info("no candidate locations at all (no $VIRTUAL_ENV, no project root)")
  end

  vim.health.info(
    "Setup runs eagerly; each notebook read resolves jupytext venv-first. "
      .. "Without a converter, the read wrapper shows raw JSON. See lua/plugins/jupytext.lua."
  )
end

return M
