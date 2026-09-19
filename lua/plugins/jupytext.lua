-- ~/.config/nvim/lua/plugins/jupytext.lua
-- Jupyter notebook support: .ipynb edited as markdown, converted on read/write.

-- Notebooks are edited as markdown. Jupyter itself lives in the per-project
-- venv here, never system-wide, so the CLI this depends on is not guaranteed
-- to exist -- which is what the guard below is about.
return {
  {
    "GCBallesteros/jupytext.nvim",
    -- lazy = false, NOT ft = "ipynb": Neovim detects .ipynb as `json`, so that
    -- filetype never matches, and all of this plugin's wiring is inside setup()
    -- (there is no plugin/ dir), so it has to load eagerly to intercept a
    -- notebook at all. It shipped as ft = "ipynb" from the first commit here and
    -- therefore never once loaded.
    lazy = false,
    config = function()
      -- Resolution happens PER NOTEBOOK OPEN, not once at startup. That matters
      -- because jupyter lives in per-project venvs here: activating one after
      -- nvim is already running (a :terminal `uv pip install jupytext`, or a
      -- direnv that fired later) used to leave notebooks opening as raw JSON
      -- until :restart. The wrapper below re-resolves on every read instead.
      --
      -- The search order itself lives in config/jupytext_resolve.lua, shared
      -- with the healthcheck so the two cannot disagree.
      local resolve = require("config.jupytext_resolve").resolve

      -- setup() unconditionally now. That is only safe because the wrapper below
      -- never delegates to jupytext without a resolved binary -- which is the
      -- whole point, since its read path DESTROYS notebooks when the CLI is
      -- missing: it runs a bare `jupytext` through the shell (commands.lua:4,
      -- no option for the path), and on failure still proceeds, because
      -- `if vim.fn.filereadable(f) then` treats filereadable()'s 0 as truthy
      -- (init.lua:88, making the error on :92 unreachable). The buffer is left
      -- empty and the next :w writes it back -- measured, 933 bytes and 3 cells
      -- down to 0.
      -- setup() asserts its arguments with vim.validate{<table>}, the form
      -- deprecated in 0.11 and due for removal in Nvim 1.0: it warns in
      -- :checkhealth today (init.lua:163 and :166) and will throw later, taking
      -- notebook support with it. No upstream fix is coming -- the last commit
      -- is 2024-04-05 and the pinned one IS origin/HEAD. Both calls only assert
      -- that the three literals below are a table and two strings, so dropping
      -- them for the duration of the call gives up no checking that could fail.
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
