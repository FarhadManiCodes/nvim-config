-- ~/.config/nvim/lua/plugins/jupytext.lua
-- Jupyter notebook support: .ipynb edited as markdown, converted on read/write.

return {
  {
    "GCBallesteros/jupytext.nvim",
    -- .ipynb is detected as JSON, so ft = "ipynb" never fires. Setup must run
    -- eagerly to register the read handler before the first notebook opens.
    lazy = false,
    config = function()
      -- Resolve per read to pick up late venv activation; share the lookup
      -- order with the healthcheck.
      local resolve = require("config.jupytext_resolve").resolve

      -- Setup is unconditional; the wrapper below guards conversion. Upstream
      -- treats filereadable()'s 0 as truthy after failed conversion, leaving an
      -- empty buffer that can truncate the notebook on save.
      -- Suppress setup's deprecated vim.validate(table) calls, which only check
      -- the fixed options below; restore validation even if setup fails.
      -- Full upstream failure details are in docs/architecture.md.
      local validate = vim.validate
      vim.validate = function() end
      local setup_ok, setup_err = pcall(require("jupytext").setup, {
        style = "markdown",  -- Convert to markdown format
        output_extension = "md",
        force_ft = "markdown",
      })
      vim.validate = validate
      if not setup_ok then
        error(setup_err)
      end

      -- Replace jupytext's BufReadCmd with a guarded one. Registering an extra
      -- BufReadCmd cannot pre-empt theirs -- ALL matching BufReadCmd autocommands
      -- run (verified) -- so theirs is pulled out of nvim_get_autocmds, deleted,
      -- and re-registered behind the checks below.
      for _, ac in ipairs(vim.api.nvim_get_autocmds({
        event = "BufReadCmd",
        pattern = "*.ipynb",
      })) do
        if ac.callback then
          local inner = ac.callback
          vim.api.nvim_del_autocmd(ac.id)
          vim.api.nvim_create_autocmd("BufReadCmd", {
            pattern = "*.ipynb",
            group = ac.group,
            callback = function(args)
              -- Show the notebook as-is. This is the safe fallback and has to be
              -- explicit: a BufReadCmd REPLACES the read, so returning without
              -- filling the buffer would leave it empty -- and an empty buffer
              -- over a real notebook is one :w away from destroying it.
              local function raw()
                pcall(
                  vim.api.nvim_buf_set_lines,
                  args.buf, 0, -1, false, vim.fn.readfile(args.file)
                )
                vim.bo[args.buf].modified = false
                vim.bo[args.buf].filetype = "json"
              end

              -- A notebook that does not exist yet, i.e. creating one. BufReadCmd
              -- fires for those too, and jupytext's utils.lua:16 calls
              -- `io.open(f, "r"):read "a"` with no nil check.
              if vim.fn.filereadable(args.file) ~= 1 then
                return
              end

              local bin = resolve()
              if not bin then
                raw()
                return
              end

              -- The plugin cannot be told which binary to use, so the resolved
              -- one goes to the front of PATH. Done here rather than at startup
              -- so a venv activated mid-session is picked up.
              local dir = vim.fn.fnamemodify(bin, ":h")
              if not vim.tbl_contains(vim.split(vim.env.PATH or "", ":", { plain = true }), dir) then
                vim.env.PATH = dir .. ":" .. vim.env.PATH
              end

              -- Malformed, truncated or 0-byte .ipynb: vim.json.decode throws,
              -- or utils.lua:17 indexes a kernelspec that is not there.
              local ok, err = pcall(inner, args)
              if not ok then
                raw()
                vim.notify(
                  "jupytext could not read this notebook, showing raw JSON: " .. tostring(err),
                  vim.log.levels.WARN
                )
              end
              -- No return value on purpose: a truthy return DELETES the autocmd.
            end,
          })
        end
      end
    end,
  },
}
