-- ~/.config/nvim/lua/plugins/init.lua
-- Complete plugin configuration - Updated for Data Engineering Workflow
-- Reviewed and optimized: December 2025

return {
  -- ==========================================================================
  -- CORE EDITING ENHANCEMENTS
  -- ==========================================================================

  {
    "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup({
        -- Configuration here, or leave empty to use defaults
      })
    end
  },

  {
    "Wansmer/treesj",
    keys = {
      { "gS", function() require('treesj').split() end, desc = "Split code structure" },
      { "gJ", function() require('treesj').join() end, desc = "Join code structure" },
      { "gM", function() require('treesj').toggle() end, desc = "Toggle split/join" },
    },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require('treesj').setup({
        use_default_keymaps = false,
        check_syntax_error = true,
        max_join_length = 120,  -- Default for most languages
        cursor_behavior = 'hold',
        notify = true,

        langs = {
          -- ====================================================================
          -- PYTHON
          -- ====================================================================
          python = {
            -- Python: trailing commas are best practice (PEP 8, Black)
            -- Black uses 88, but we prefer 100 for readability
            argument_list = { split = { last_separator = true, max_length = 100 } },
            list = { split = { last_separator = true, max_length = 100 } },
            dictionary = { split = { last_separator = true, max_length = 100 } },
          },

          -- ====================================================================
          -- GO
          -- ====================================================================
          go = {
            -- Go: ONLY composite literals allow trailing commas
            -- Function calls do NOT allow them (syntax error)
            -- gofmt standard: 80 chars, but we use 100 for consistency

            -- Composite literals (structs, slices, maps) - NEED trailing comma
            literal_value = { split = { last_separator = true, max_length = 100 } },

            -- Function/method calls - NO trailing comma
            argument_list = { split = { last_separator = false, max_length = 100 } },
            parameter_list = { split = { last_separator = false, max_length = 100 } },
          },

          -- ====================================================================
          -- SCALA
          -- ====================================================================
          scala = {
            -- Scala: trailing commas are recommended (Scala 2.12.2+)
            arguments = { split = { last_separator = true } },
            parameters = { split = { last_separator = true } },
            tuple = { split = { last_separator = true } },
          },

          -- ====================================================================
          -- YAML
          -- ====================================================================
          yaml = {
            -- YAML: NO trailing commas (syntax error in YAML!)
            block_mapping_pair = { split = { last_separator = false } },
            flow_sequence = { split = { last_separator = false } },
            flow_mapping = { split = { last_separator = false } },
          },

          -- ====================================================================
          -- TOML
          -- ====================================================================
          toml = {
            -- TOML: trailing commas ARE allowed in arrays (TOML spec)
            array = { split = { last_separator = true } },
            inline_table = { split = { last_separator = false } },
          },

          -- ====================================================================
          -- C
          -- ====================================================================
          c = {
            -- C: NO trailing commas (syntax error!)
            argument_list = { split = { last_separator = false } },
            parameter_list = { split = { last_separator = false } },
            initializer_list = { split = { last_separator = false } },
          },

          -- ====================================================================
          -- C++
          -- ====================================================================
          cpp = {
            -- C++: NO trailing commas (syntax error!)
            -- Google style guide: 80 chars, but we use 100
            argument_list = { split = { last_separator = false, max_length = 100 } },
            parameter_list = { split = { last_separator = false, max_length = 100 } },
            initializer_list = { split = { last_separator = false, max_length = 100 } },
            template_argument_list = { split = { last_separator = false, max_length = 100 } },
          },
        },
      })
    end,
  },

  {
    "echasnovski/mini.bracketed",
    version = "*",
    event = "VeryLazy",
    config = function()
      -- Only modules with NO Neovim built-in equivalent. Neovim 0.11+ already
      -- ships ]b/[b (:bnext), ]d/[d (vim.diagnostic.jump), ]q/[q (:cnext) and
      -- ]l/[l (:lnext), so enabling those here just re-implemented built-ins.
      -- The one behaviour given up is wrap-around: native :cnext stops at the
      -- last entry with E553 where mini cycles. Judged not worth a shadowing
      -- layer over three built-ins.
      require("mini.bracketed").setup({
        file     = { suffix = 'f' },  -- ]f [f  next/prev file in the directory
        indent   = { suffix = 'i' },  -- ]i [i  next/prev line at a different
                                      --        indent -- earns its keep in
                                      --        Python and YAML, no built-in
        conflict = { suffix = 'x' },  -- ]x [x  merge-conflict markers; this repo
                                      --        merges --no-ff, so they happen
        yank     = { suffix = 'y' },  -- ]y [y  cycle yank history after a paste

        -- Off because Neovim provides them:
        buffer     = { suffix = '' },  -- ]b  :bnext
        diagnostic = { suffix = '' },  -- ]d  vim.diagnostic.jump
        quickfix   = { suffix = '' },  -- ]q  :cnext
        location   = { suffix = '' },  -- ]l  :lnext

        -- Off because the key belongs to something else, or a built-in is
        -- better. These are load-bearing, not tidying: `comment` would take ]c
        -- from gitsigns' hunk navigation, and `treesitter` would take ]t from
        -- the built-in :tnext tag jump.
        comment    = { suffix = '' },
        treesitter = { suffix = '' },
        jump       = { suffix = '' },  -- <C-o>/<C-i> already walk the jumplist
        undo       = { suffix = '' },  -- g-/g+ already walk undo states
        oldfile    = { suffix = '' },  -- <leader>fo (Telescope oldfiles)
        window     = { suffix = '' },  -- <C-w>w
      })
    end,
  },

  -- ==========================================================================
  -- AUTO-PAIRS
  -- ==========================================================================

  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      local npairs = require("nvim-autopairs")
      local Rule = require('nvim-autopairs.rule')

      npairs.setup({
        check_ts = true,
        ts_config = {
          lua = { "string" },
          javascript = { "template_string" },
          python = { "string" },  -- Don't autopair inside Python strings
          java = false,
        },
        disable_filetype = { "TelescopePrompt", "vim" },
        -- fast_wrap removed - using nvim-surround instead
      })

      -- Python triple quotes for docstrings
      npairs.add_rules({
        Rule('"""', '"""', 'python'),
        Rule("'''", "'''", 'python'),
      })

    end,
  },

  -- ==========================================================================
  -- TMUX INTEGRATION
  -- ==========================================================================

  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
    },
    keys = {
      { "<c-h>", "<cmd>TmuxNavigateLeft<cr>" },
      { "<c-j>", "<cmd>TmuxNavigateDown<cr>" },
      { "<c-k>", "<cmd>TmuxNavigateUp<cr>" },
      { "<c-l>", "<cmd>TmuxNavigateRight<cr>" },
      { "<c-\\>", "<cmd>TmuxNavigatePrevious<cr>" },
    },
  },

  -- ==========================================================================
  -- SESSION MANAGEMENT
  -- ==========================================================================

  {
    "tpope/vim-obsession",
    lazy = false,  -- Load immediately
    config = function()
      -- Auto-start Obsession in git repositories
      vim.api.nvim_create_autocmd("VimEnter", {
        group = vim.api.nvim_create_augroup("ObsessionAutostart", { clear = true }),
        nested = true,
        callback = function()
          -- Only auto-start when opening bare `nvim` (no file arguments).
          if vim.fn.argc() ~= 0 then
            return
          end

          -- vim.fs.root() walks UP the tree. The old check was
          -- isdirectory('.git'), which only looked at the launch directory, so
          -- `nvim` from any subdirectory of a project silently got no session
          -- tracking at all — and never from a git worktree either, where .git
          -- is a file rather than a directory. fs.root handles both.
          local root = vim.fs.root(vim.uv.cwd(), ".git")
          if not root then
            return
          end

          vim.defer_fn(function()
            -- Started via `nvim -S Session.vim`? Obsession is already tracking;
            -- re-issuing :Obsession would repoint it and clobber that session.
            if vim.g.this_obsession then
              return
            end
            -- Write to the ROOT, not the cwd. :Obsession with no argument uses
            -- the current directory, which after the fix above would scatter a
            -- Session.vim into every subdirectory nvim was launched from.
            vim.cmd('Obsession ' .. vim.fn.fnameescape(root .. '/Session.vim'))
          end, 100)
        end,
      })
    end,
  },

  -- ==========================================================================
  -- GIT INTEGRATION
  -- ==========================================================================

  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add          = { text = '│' },
        change       = { text = '│' },
        delete       = { text = '_' },
        topdelete    = { text = '‾' },
        changedelete = { text = '~' },
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns

        -- Navigate between changes. nav_hunk(), not the next_hunk/prev_hunk
        -- pair — those are marked @deprecated in gitsigns/actions.lua and route
        -- through a shim that will eventually be removed.
        vim.keymap.set('n', ']c', function() gs.nav_hunk('next') end, { buffer = bufnr, desc = "Next git hunk" })
        vim.keymap.set('n', '[c', function() gs.nav_hunk('prev') end, { buffer = bufnr, desc = "Previous git hunk" })

        -- Actions
        vim.keymap.set('n', '<leader>hp', gs.preview_hunk, { buffer = bufnr, desc = "Preview hunk" })
        vim.keymap.set('n', '<leader>hr', gs.reset_hunk, { buffer = bufnr, desc = "Reset hunk" })
        vim.keymap.set('n', '<leader>hs', gs.stage_hunk, { buffer = bufnr, desc = "Stage hunk" })
      end,
    },
  },

  -- ==========================================================================
  -- DATABASE INTERACTION
  -- ==========================================================================

  {
    "tpope/vim-dadbod",
    cmd = "DB",
    ft = { "sql", "mysql", "plsql" },
    config = function()
      -- No g:dbs table here on purpose. g:dbs is vim-dadbod-UI's setting, not
      -- vim-dadbod's — the whole dadbod source contains no reference to it (the
      -- sole "dbs" match is `dbsize` in the redis adapter), and dadbod-ui is not
      -- installed. A populated g:dbs would therefore have done nothing at all,
      -- while looking exactly like working configuration.
      --
      -- vim-dadbod resolves a connection from, in order: t:db, b:db,
      -- $DATABASE_URL, g:db (:h dadbod). So either pass a URL inline —
      --   :DB postgresql://localhost/dev select 1
      -- or set a default for a buffer/project, e.g. from .nvim.lua (exrc is on):
      --   vim.b.db = "postgresql://localhost/dev_db"
      -- Never hardcode credentials; read them with os.getenv().
      --
      -- Install kristijanhusak/vim-dadbod-ui if the named-connection sidebar is
      -- ever wanted — that is what makes a g:dbs table meaningful.

      -- Quick execution keybindings in SQL files
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "sql", "mysql", "plsql" },
        callback = function()
          vim.keymap.set("n", "<leader>rr", ":.DB<CR>", { buffer = true, desc = "Execute query line" })
          vim.keymap.set("v", "<leader>rr", ":DB<CR>", { buffer = true, desc = "Execute query selection" })
          vim.keymap.set("n", "<leader>rf", ":%DB<CR>", { buffer = true, desc = "Execute entire file" })
        end,
      })
    end,
  },

  -- ==========================================================================
  -- CSV FILE HANDLING
  -- ==========================================================================

  {
    "mechatroner/rainbow_csv",
    ft = { "csv", "tsv", "csv_semicolon", "csv_pipe" },
    config = function()
      -- No g:rcsv_align_mode: not a rainbow_csv option. The plugin reads eight
      -- g: variables and documents fourteen; that name is in neither, and does
      -- not appear anywhere in its source. Nor is there a mode to disable --
      -- alignment is :RainbowAlign, a command. g:rcsv_max_columns (default 30)
      -- is the real knob if a wide file ever gets slow.

      -- Keybindings for CSV-specific operations
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "csv", "tsv" },
        callback = function()
          -- <leader>cc REWRITES the buffer (setline, padding every field);
          -- upstream warns against it where surrounding whitespace is data.
          -- <leader>cs is the inverse, so a mis-hit is recoverable without undo.
          vim.keymap.set("n", "<leader>cc", "<cmd>RainbowAlign<cr>",
            { buffer = true, desc = "Align CSV columns (edits the buffer)" })
          vim.keymap.set("n", "<leader>cs", "<cmd>RainbowShrink<cr>",
            { buffer = true, desc = "Un-align CSV columns (strip padding)" })
          vim.keymap.set("n", "<leader>cq", ":Select ",
            { buffer = true, desc = "RBQL query" })
        end,
      })
    end,
  },

  -- ==========================================================================
  -- ENVIRONMENT VARIABLE PLUGIN
  -- ==========================================================================

  {
    "FarhadManiCodes/vim-envx",
    ft = { "sh", "bash", "zsh", "yaml", "dockerfile", "toml" },
    keys = {
      { "<leader>ev", mode = { "n", "x" }, desc = "Expand env variable" },
      { "<leader>eev", mode = "n", desc = "Expand all env vars on line" },
      { "<leader>ex", mode = "x", desc = "Extract as env variable" },
    },
  },

  -- ==========================================================================
  -- TELESCOPE (Fuzzy Finder)
  -- ==========================================================================

  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
      },
    },
    cmd = "Telescope",
    keys = {
      -- File finding (replaces FZF Ctrl+p)
      { "<C-p>", "<cmd>Telescope find_files<cr>", desc = "Find files" },

      -- Buffer switching (replaces FZF <leader>b)
      { "<leader>bb", "<cmd>Telescope buffers<cr>", desc = "Find buffers" },

      -- Text search (replaces FZF <leader>rg)
      { "<leader>rg", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },

      -- Search in buffer (replaces FZF <leader>/)
      { "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "Search in buffer" },

      -- Additional useful pickers
      { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help tags" },
      { "<leader>fr", "<cmd>Telescope resume<cr>", desc = "Resume last search" },
      { "<leader>fo", "<cmd>Telescope oldfiles<cr>", desc = "Recent files" },
      { "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>", desc = "Document symbols" },
      { "<leader>fS", "<cmd>Telescope lsp_workspace_symbols<cr>", desc = "Workspace symbols" },

      -- Git integration
      { "<leader>gc", "<cmd>Telescope git_commits<cr>", desc = "Git commits" },
      { "<leader>gs", "<cmd>Telescope git_status<cr>", desc = "Git status" },
    },
    config = function()
      local telescope = require("telescope")
      local actions = require("telescope.actions")

      telescope.setup({
        defaults = {
          -- Layout configuration
          layout_strategy = "horizontal",
          layout_config = {
            horizontal = {
              preview_width = 0.55,
              prompt_position = "top",
            },
            width = 0.87,
            height = 0.80,
          },

          sorting_strategy = "ascending",

          -- Keybindings inside telescope
          mappings = {
            i = {
              ["<C-j>"] = actions.move_selection_next,
              ["<C-k>"] = actions.move_selection_previous,
              ["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
              ["<Esc>"] = actions.close,
            },
            n = {
              ["q"] = actions.close,
            },
          },

          -- File ignore patterns
          file_ignore_patterns = {
            "node_modules",
            ".git/",
            "__pycache__/",
            "%.pyc",
            ".venv/",
            "venv/",

            -- C/C++ Build Systems
            "build/",
            "Build/",
            "BUILD/",
            "cmake%-build%-.*/",     -- cmake-build-debug, cmake-build-release, etc.
            "builddir/",             -- Meson
            "meson%-build/",         -- Meson alternative
            "CMakeFiles/",
            "CMakeCache%.txt",

            -- C/C++ Build Artifacts
            "%.o$",                  -- Object files
            "%.so$",                 -- Shared libraries (Linux)
            "%.so%.%d+$",            -- Versioned shared libraries (libfoo.so.1)
            "%.a$",                  -- Static libraries
            "%.dylib$",              -- Shared libraries (macOS)
            "%.out$",                -- Output executables
            "a%.out$",               -- Default executable name
            "%.exe$",                -- Windows executables
          },

          -- Ripgrep configuration
          vimgrep_arguments = {
            "rg",
            "--color=never",
            "--no-heading",
            "--with-filename",
            "--line-number",
            "--column",
            "--smart-case",
            "--hidden",
            "--glob=!.git/",
          },
        },

        pickers = {
          find_files = {
            hidden = true,
            find_command = vim.fn.executable("fd") == 1 and {
              "fd",
              "--type", "f",
              "--hidden",
              "--exclude", ".git",
            } or {
              "rg",
              "--files",
              "--hidden",
              "--glob", "!.git/*",
            },
          },

          buffers = {
            sort_lastused = true,
            mappings = {
              i = {
                ["<C-d>"] = actions.delete_buffer,
              },
            },
          },

          live_grep = {
            additional_args = function()
              return { "--hidden" }
            end,
          },
        },
      })

      -- Load fzf extension for better performance
      pcall(telescope.load_extension, "fzf")
    end,
  },

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
  -- FILE EXPLORER
  -- ==========================================================================

  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    -- lazy = false is required by default_file_explorer below, not a preference.
    -- Oil installs its directory hijack as a BufAdd autocmd at setup() time
    -- (oil/init.lua:1403), so with oil loaded on `cmd`/`keys` the autocmd does
    -- not exist yet when `nvim .` adds the buffer -- and netrw is disabled in
    -- config/lazy.lua, so nothing handled it and you got an empty buffer with no
    -- filetype. Pressing `-` recovered it, which is why this stayed unnoticed.
    lazy = false,
    cmd = "Oil",
    keys = {
      { "-", "<cmd>Oil<cr>", desc = "Open parent directory" },
      { "<leader>-", function() require("oil").open_float() end, desc = "Open Oil (floating)" },
    },
    opts = {
      default_file_explorer = true,

      columns = {
        "icon",
        "size",  -- Human-readable file sizes
      },

      keymaps = {
        ["g?"] = "actions.show_help",
        ["<CR>"] = "actions.select",
        ["<C-s>"] = "actions.select_vsplit",
        -- <C-x>, not oil's default <C-h>: <C-h/j/k/l> are vim-tmux-navigator's
        -- split/pane movement everywhere else, and a buffer-local map wins over
        -- a global one, so oil was the single place those four keys did not
        -- navigate. Trade-off: <C-x> otherwise falls through to the built-in
        -- decrement-number, which is now unavailable while renaming in oil.
        ["<C-x>"] = "actions.select_split",
        -- Explicit false is REQUIRED to drop oil's default: this table is
        -- merged into oil's defaults, not substituted for them, so simply
        -- omitting <C-h> leaves oil's own binding in place (see :h oil-config,
        -- "Set to `false` to remove a keymap").
        ["<C-h>"] = false,
        ["<C-t>"] = "actions.select_tab",
        ["<C-p>"] = "actions.preview",
        ["<C-c>"] = "actions.close",
        ["<C-r>"] = "actions.refresh",
        ["-"] = "actions.parent",
        ["_"] = "actions.open_cwd",
        ["`"] = "actions.cd",
        ["~"] = "actions.tcd",
        ["gs"] = "actions.change_sort",
        ["gx"] = "actions.open_external",
        ["g."] = "actions.toggle_hidden",
        ["g\\"] = "actions.toggle_trash",
        ["gy"] = "actions.copy_entry_path",  -- Copy file path!
      },

      delete_to_trash = true,  -- Requires trash-cli
      skip_confirm_for_simple_edits = true,

      view_options = {
        show_hidden = true,  -- Show hidden files by default

        -- Hide ONLY .git directory
        is_hidden_file = function(name, bufnr)
          return name == ".git"
        end,

        is_always_hidden = function(name, bufnr)
          return false
        end,

        natural_sort = true,

        sort = {
          { "type", "asc" },  -- Directories first
          { "name", "asc" },
        },
      },

      float = {
        padding = 2,
        max_width = 90,
        max_height = 30,
        border = "rounded",
        win_options = {
          winblend = 0,
        },
      },

      preview = {
        max_width = 0.9,
        min_width = { 40, 0.4 },
        max_height = 0.9,
        min_height = { 5, 0.1 },
        border = "rounded",
      },
    },
  },

  -- ==========================================================================
  -- STATUSLINE
  -- ==========================================================================

  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    opts = {
      options = {
        theme = "auto",  -- Automatically matches your colorscheme
        component_separators = { left = '', right = '' },
        section_separators = { left = '', right = '' },
        globalstatus = true,  -- Single statusline for all windows (modern)
        disabled_filetypes = {
          statusline = { "dashboard", "alpha", "starter" },
        },
      },

      sections = {
        -- Left side: mode, filename, git branch
        lualine_a = {
          {
            "mode",
            fmt = function(str)
              -- Shorten mode names: NORMAL → N, INSERT → I, etc.
              return str:sub(1, 1)
            end,
          },
        },
        lualine_b = {
          {
            "filename",
            path = 0,  -- Just filename, no path
            symbols = {
              modified = " [+]",
              readonly = " []",
              unnamed = "[No Name]",
            },
          },
        },
        lualine_c = {
          {
            "branch",
            icon = "",
          },
        },

        -- Right side: python env, diagnostics
        lualine_x = {
          -- Python virtual environment (like your old VirtualEnvStatus)
          {
            function()
              local venv = os.getenv("VIRTUAL_ENV")
              if venv then
                return "  " .. vim.fn.fnamemodify(venv, ":t")
              end
              return ""
            end,
            cond = function()
              return vim.bo.filetype == "python"
            end,
          },

          -- LSP diagnostics (replaces ALE - will show when LSP is added)
          {
            "diagnostics",
            sources = { "nvim_lsp" },
            symbols = {
              error = " ",
              warn = " ",
              info = " ",
              hint = " ",
            },
          },
        },
        lualine_y = {},  -- Removed progress (45%)
        lualine_z = {},  -- Removed location (145:23)
      },

      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { "filename" },
        lualine_x = { "location" },
        lualine_y = {},
        lualine_z = {},
      },

      extensions = { "oil", "lazy" },
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
      require("jupytext").setup({
        style = "markdown",  -- Convert to markdown format
        output_extension = "md",
        force_ft = "markdown",
      })

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

  -- ==========================================================================
  -- ICONS
  -- ==========================================================================

  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
    config = function()
      require("nvim-web-devicons").setup({
        default = true,
      })
    end,
  },

  -- ==========================================================================
  -- DEPENDENCIES
  -- ==========================================================================

  {
    "nvim-lua/plenary.nvim",
    lazy = true,
  },

  -- ==========================================================================
  -- LSP AND COMPLETION
  -- ==========================================================================
  -- Note: Using Neovim 0.11+ native vim.lsp.config API (no nvim-lspconfig plugin needed)
  -- LSP servers configured in lua/config/lsp.lua

  -- Completion Engine: blink.cmp (Rust fuzzy matcher; built-in lsp/buffer/path/
  -- cmdline/snippet sources). Loads at STARTUP, not lazily: lsp.lua calls
  -- require('blink.cmp').get_lsp_capabilities() during the plugins phase, which
  -- forces the load anyway — and blink's startup cost is ~1ms-class. This single
  -- plugin replaces nvim-cmp + cmp-nvim-lsp/buffer/path/cmdline/omni (6 → 1).
  --
  -- version = '1.*' pulls the prebuilt fuzzy binary (no Rust/cargo build needed).
  -- nvim-autopairs is unaffected: blink's completion.accept.auto_brackets handles
  -- parens after completion, so the old cmp_autopairs.on_confirm_done hook is gone.
  {
    "saghen/blink.cmp",
    version = "1.*",
    config = function()
      require("config.completion")
    end,
  },
}
