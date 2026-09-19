-- ~/.config/nvim/lua/plugins/documents.lua
-- Long-form document editing: LaTeX, Typst, Markdown rendering.
-- Notebooks live in plugins/jupytext.lua, focus dimming in plugins/ui.lua.

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
  -- TYPST (modern typesetting; LSP = tinymist, configured in lsp/tinymist.lua)
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
}
