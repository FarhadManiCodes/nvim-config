-- ~/.config/nvim/lua/plugins/documents.lua
-- Long-form document and notebook editing: LaTeX, Typst, Markdown rendering,
-- distraction-free writing, Jupyter notebooks (edited as markdown).

return {
  -- ==========================================================================
  -- LATEX EDITING
  -- ==========================================================================

  {
    "lervag/vimtex",
    ft = "tex",
    cmd = "VimtexInverseSearch",
    config = function()
      -- PDF Viewer: sioyek (Wayland-native, SyncTeX forward search built in)
      vim.g.vimtex_view_method = 'sioyek'
      -- Reuse the existing sioyek window so --inverse-search stays in effect
      vim.g.vimtex_view_sioyek_options = '--reuse-window'
      -- Compiler
      vim.g.vimtex_compiler_method = "latexmk"

      -- Auto-compile and update PDF on save
      vim.g.vimtex_compiler_latexmk = {
        build_dir = "",
        callback = 1,
        continuous = 1,
        executable = "latexmk",
        options = {
          "-pdf",
          "-verbose",
          "-file-line-error",
          "-synctex=1",
          "-interaction=nonstopmode",
        },
      }

      -- Jump to current position in sioyek on first open
      vim.g.vimtex_view_forward_search_on_start = 1

      -- Completion (vimtex omnifunc; used via manual <C-x><C-o>)
      vim.g.vimtex_complete_enabled = 1
      vim.g.vimtex_complete_close_braces = 1

      -- Bibliography backend (biblatex/biber is default)
      vim.g.vimtex_parser_bib_backend = 'bibparse'

      -- TOC settings
      vim.g.vimtex_toc_config = {
        split_pos = "vert leftabove",
        split_width = 30,
      }

      -- Folding
      vim.g.vimtex_fold_enabled = 0

      -- Suppress some warnings
      vim.g.vimtex_quickfix_ignore_filters = {
        "Underfull",
        "Overfull",
      }

      -- Inverse search: after VimtexInverseSearch jumps, focus the nvim terminal.
      -- xdo_focus_vim() (vimtex's built-in) uses xdotool which is X11-only.
      -- This replaces it for Wayland/niri.
      -- Match the foot window by title containing "NVIM" (set by titlestring):
      -- contains() not startswith() so it also matches in tmux, where set-titles
      -- wraps it as `#S:#I:#W - "NVIM - file"`. Fall back to the first foot window.
      vim.api.nvim_create_autocmd("User", {
        pattern = "VimtexEventViewReverse",
        callback = function()
          vim.fn.jobstart({
            "bash", "-c",
            "ID=$(niri msg --json windows | jq -r '"
              .. "([.[] | select(.app_id == \"foot\" and (.title | contains(\"NVIM\")))] | first | .id)"
              .. " // ([.[] | select(.app_id == \"foot\")] | first | .id)"
              .. " // empty'); "
              .. "[[ -n \"$ID\" ]] && niri msg action focus-window --id \"$ID\""
          }, { detach = true })
        end,
      })

      -- Keybindings for .tex files
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "tex",
        callback = function()
          -- Ensure vimtex omnifunc is set (for manual <C-x><C-o> completion)
          vim.bo.omnifunc = "vimtex#complete#omnifunc"

          -- Sync refs.bib from papis (additive) just before compiling, so a
          -- freshly-cited paper resolves on the first pass. Shared with the
          -- typst spec below — see lua/config/papis_bib.lua for the additive-vs-
          -- prune contract and why the call is synchronous.
          -- vimtex knows the project's main file; fall back to this buffer.
          vim.keymap.set("n", "<leader>ll", function()
            require("config.papis_bib").sync((vim.b.vimtex and vim.b.vimtex.tex) or vim.fn.expand("%:p"))
            vim.cmd("VimtexCompile")
          end, { buffer = true, desc = "Sync refs.bib (papis) + compile LaTeX" })
          vim.keymap.set("n", "<leader>lv", "<cmd>VimtexView<cr>", { buffer = true, desc = "View PDF" })
          vim.keymap.set("n", "<leader>lt", "<cmd>VimtexTocToggle<cr>", { buffer = true, desc = "Toggle TOC" })
          vim.keymap.set("n", "<leader>lc", "<cmd>VimtexClean<cr>", { buffer = true, desc = "Clean aux files" })
          vim.keymap.set("n", "<leader>ls", "<cmd>VimtexStop<cr>", { buffer = true, desc = "Stop compilation" })
          -- <leader>lb: interactive bib cleanup. Same binding on typst.
          require("config.papis_bib").map_prune()
        end,
      })
    end,
  },

  -- ==========================================================================
  -- TYPST (modern typesetting; LSP = tinymist, configured in config/lsp.lua)
  -- ==========================================================================
  -- No compiler plugin: tinymist is the LSP and drives the preview server.
  -- This plugin only bridges nvim ↔ that server for a live, cursor-synced
  -- browser preview (bidirectional, better than SyncTeX). PDF export is the
  -- LSP's exportPdf=onSave; formatting is the LSP (typstyle). Keymaps reuse
  -- the <leader>l prefix so muscle memory carries over from vimtex.

  {
    "chomosuke/typst-preview.nvim",
    ft = "typst",
    version = "1.*",
    opts = {
      -- Use the system tinymist from extra, not an auto-downloaded copy —
      -- keeps the binary pacman-managed and in lockstep with the LSP.
      dependencies_bin = { ["tinymist"] = "tinymist" },
      -- Open the preview in Firefox (a new window in the running session).
      -- vimb (WebKitGTK) was tried first but could not render typst-preview's
      -- incremental canvas — it composited later pages on top of page 1. Firefox
      -- renders typst.ts correctly and gives bidirectional cursor sync. It can't
      -- be isolated into its own niri app-id while the main instance runs
      -- (Wayland app_id stays "firefox"), so it tiles via the existing firefox
      -- window-rule rather than a dedicated 0.5 column. >/dev/null 2>&1: the
      -- plugin treats ANY stderr as "opening link failed" (utils.lua visit()),
      -- and `firefox --new-window` to a live instance is chatty; the window
      -- still opens, only the false error message is suppressed.
      -- Run <leader>ll on the project's ROOT file (e.g. main.typ) so the whole
      -- multi-file document is previewed, not a standalone #include'd fragment.
      open_cmd = "firefox --new-window %s >/dev/null 2>&1",
    },
    config = function(_, opts)
      require("typst-preview").setup(opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "typst",
        callback = function()
          -- <leader>ll: sync refs.bib from papis (additive, same helper as the
          -- vimtex hook), then start the live preview. Safe to re-hit while the
          -- preview runs — papis-bib rewrites refs.bib only on change and the
          -- live preview re-renders.
          -- No <leader>lv: TypstPreview already toggles/opens, so a separate
          -- "view" map (needed for vimtex's compile-then-view split) is redundant.
          vim.keymap.set("n", "<leader>ll", function()
            require("config.papis_bib").sync(vim.fn.expand("%:p"))
            vim.cmd("TypstPreview")
          end, { buffer = true, desc = "Sync refs.bib (papis) + Typst preview" })
          -- <leader>ls: stop the preview server (mirrors VimtexStop).
          vim.keymap.set("n", "<leader>ls", "<cmd>TypstPreviewStop<cr>",
            { buffer = true, desc = "Stop Typst preview" })
          -- <leader>lp: jump the preview to the cursor's position.
          vim.keymap.set("n", "<leader>lp", "<cmd>TypstPreviewSyncCursor<cr>",
            { buffer = true, desc = "Sync preview to cursor" })
          -- <leader>lb: interactive bib cleanup. Same binding on tex.
          require("config.papis_bib").map_prune()
        end,
      })
    end,
  },

  -- ==========================================================================
  -- MARKDOWN EDITING
  -- ==========================================================================

  {
    "MeanderingProgrammer/render-markdown.nvim",
    -- markdown only. Upstream's README also lists "Avante" (avante.nvim renders
    -- its AI output through this plugin); that is not installed here, so the
    -- trigger could never fire and only implied a dependency we don't have.
    ft = "markdown",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = {
      code = {
        sign = false,
        width = "block",
        right_pad = 1,
      },
      heading = {
        sign = false,
        icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
      },
      latex = {
        enabled = true,
        -- mathunicode only, no utftex/latex2text fallback: utftex's
        -- multi-line stacked subscripts (e.g. "phy" on a row under "u")
        -- confirmed broken here in three ways -- render-markdown's
        -- position="center" picks the "center" output line by numeric
        -- index (floor(#output/2)+1), not by which line is the actual
        -- content, so (1) the real equation text ends up in a separately
        -- positioned virt_lines block computed from a preceding-text
        -- width that breaks for longer prefixes, (2) only the "center"
        -- line's node extent gets concealed, leaving the raw $$...$$
        -- source partially visible alongside the render, and (3) closing
        -- delimiters on multi-line block equations don't conceal
        -- correctly either. mathunicode never produces multi-line output
        -- (pylatexenc always linearizes to one flat string), so this
        -- whole code path can't trigger; it also does real Unicode
        -- sub/superscript substitution where possible (see
        -- ~/projects/mathunicode).
        converter = { "mathunicode" },
        highlight = "RenderMarkdownMath",
        top_pad = 0,
        bottom_pad = 0,
      },
      -- Integrated callouts (obsidian style)
      callout = {
        note = { raw = "[!NOTE]", rendered = "󰋽 Note", highlight = "RenderMarkdownInfo" },
        tip = { raw = "[!TIP]", rendered = "󰌶 Tip", highlight = "RenderMarkdownSuccess" },
        warning = { raw = "[!WARNING]", rendered = "󰀪 Warning", highlight = "RenderMarkdownWarn" },
      },
    },
  },

  -- ==========================================================================
  -- DISTRACTION-FREE WRITING
  -- ==========================================================================

  {
    "folke/twilight.nvim",
    cmd = { "Twilight", "TwilightEnable", "TwilightDisable" },
    keys = {
      { "<leader>tt", "<cmd>Twilight<cr>", desc = "Toggle Twilight (focus)" },
    },
    -- One alpha, no per-background branch. What that branch used to do:
    --
    --   * The hex colours (#1a1a1a / #f5f5f5) were never read. config.colors()
    --     walks dimming.color in order and stops at the first entry that
    --     resolves; "Normal" comes first, so it always blended that group's
    --     foreground and never reached the hex. Editing those values did
    --     nothing, which is exactly the kind of live-looking dead config this
    --     audit keeps finding.
    --   * The alpha was chosen once, when the plugin loaded, so it could not
    --     follow <leader>th. Toggling to dark kept the light alpha.
    --   * twilight already follows theme changes on its own -- view.lua:20
    --     installs a ColorScheme autocmd that re-derives the dim colour from
    --     Normal -- so nothing here needed to.
    --
    -- 0.20 rather than an average: it is what a light-saved session actually
    -- used, and what was eyeballed and accepted in BOTH themes. The one real
    -- change is that nvim launched while dark is saved now dims at 0.20 instead
    -- of 0.10, i.e. the same as dark reached by toggling. Consistent either way.
    opts = {
      dimming = { alpha = 0.20, inactive = true },
      context = 15,  -- lines kept undimmed around the cursor
      -- treesitter = false dims that fixed window instead of expanding to the
      -- enclosing node. It also makes an `expand` list unreachable
      -- (view.lua:167 gates the whole treesitter branch on this flag), which is
      -- why there is no longer one here.
      treesitter = false,
    },
  },

  -- ==========================================================================
  -- JUPYTER NOTEBOOK SUPPORT
  -- ==========================================================================

  -- Notebooks are edited as markdown. Jupyter itself lives in the per-project
  -- venv here, never system-wide, so the CLI this depends on is not guaranteed
  -- to exist -- which is what the guard below is about.
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
      -- Venv-first ordering: $VIRTUAL_ENV (direnv or `va` activated something)
      -- beats a project-local .venv, which beats PATH (a uv tool install).
      local function resolve()
        local candidates = {}
        if vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV ~= "" then
          candidates[#candidates + 1] = vim.env.VIRTUAL_ENV .. "/bin/jupytext"
        end
        local root = vim.fs.root(vim.uv.cwd(), { ".venv", "pyproject.toml", ".git" })
        if root then
          candidates[#candidates + 1] = root .. "/.venv/bin/jupytext"
        end
        candidates[#candidates + 1] = vim.fn.exepath("jupytext")

        for _, path in ipairs(candidates) do
          if path ~= "" and vim.fn.executable(path) == 1 then
            return path
          end
        end
      end

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
