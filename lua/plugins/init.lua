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
      require("mini.bracketed").setup({
        -- Selective mode: only enable useful navigations
        buffer     = { suffix = 'b' },  -- [b ]b - buffer navigation
        diagnostic = { suffix = 'd' },  -- [d ]d - LSP diagnostics
        file       = { suffix = 'f' },  -- [f ]f - file navigation
        quickfix   = { suffix = 'q' },  -- [q ]q - quickfix list
        -- Disable others
        comment    = { suffix = '' },
        conflict   = { suffix = '' },
        indent     = { suffix = '' },
        jump       = { suffix = '' },
        location   = { suffix = '' },
        oldfile    = { suffix = '' },
        treesitter = { suffix = '' },
        undo       = { suffix = '' },
        window     = { suffix = '' },
        yank       = { suffix = '' },
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
          -- Only auto-start in git repos (your data projects)
          if vim.fn.argc() == 0 and vim.fn.isdirectory('.git') == 1 then
            vim.defer_fn(function()
              vim.cmd('Obsession')
            end, 100)
          end
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

        -- Navigate between changes
        vim.keymap.set('n', ']c', gs.next_hunk, { buffer = bufnr, desc = "Next git hunk" })
        vim.keymap.set('n', '[c', gs.prev_hunk, { buffer = bufnr, desc = "Previous git hunk" })

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
      -- Pre-configure your databases (use environment variables for credentials!)
      vim.g.dbs = {
        -- Example configurations - adjust to your setup:
        -- duckdb = "duckdb:~/data/analytics.duckdb",
        -- postgres_dev = string.format(
        --   "postgresql://%s:%s@localhost:5432/dev_db",
        --   os.getenv("DB_USER") or "user",
        --   os.getenv("DB_PASSWORD") or "pass"
        -- ),
        -- Add your PostgreSQL/Redshift/Trino connections here
      }

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
      -- Optional: Disable alignment if slow on large files
      vim.g.rcsv_align_mode = 0

      -- Keybindings for CSV-specific operations
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "csv", "tsv" },
        callback = function()
          vim.keymap.set("n", "<leader>cc", "<cmd>RainbowAlign<cr>",
            { buffer = true, desc = "Align CSV columns" })
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

          -- Sync refs.bib from papis (pull cited keys missing from the .bib) just
          -- before compiling, so a freshly-cited paper resolves on the first pass.
          -- Synchronous + write-only-if-changed (papis-bib), so latexmk -pvc sees a
          -- stable .bib and no compile loop.
          vim.keymap.set("n", "<leader>ll", function()
            local main = (vim.b.vimtex and vim.b.vimtex.tex) or vim.fn.expand("%:p")
            if main ~= "" then vim.fn.system({ "papis-bib", main }) end
            vim.cmd("VimtexCompile")
          end, { buffer = true, desc = "Sync refs.bib (papis) + compile LaTeX" })
          vim.keymap.set("n", "<leader>lv", "<cmd>VimtexView<cr>", { buffer = true, desc = "View PDF" })
          vim.keymap.set("n", "<leader>lt", "<cmd>VimtexTocToggle<cr>", { buffer = true, desc = "Toggle TOC" })
          vim.keymap.set("n", "<leader>lc", "<cmd>VimtexClean<cr>", { buffer = true, desc = "Clean aux files" })
          vim.keymap.set("n", "<leader>ls", "<cmd>VimtexStop<cr>", { buffer = true, desc = "Stop compilation" })
        end,
      })
    end,
  },

  -- ==========================================================================
  -- MARKDOWN EDITING
  -- ==========================================================================

  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "Avante" },
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
        -- utftex first: real multi-line positioned sub/superscripts (e.g.
        -- u_{phy} stacks "phy" under "u"), which mathunicode's flat text
        -- can't match. mathunicode only as fallback for utftex's specific
        -- gaps (\coloneqq, \land, \Pr -- confirmed utftex errors, exit 1,
        -- on exactly these three; everything else tested renders fine).
        converter = { "utftex", "mathunicode", "latex2text" },
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
    config = function()
    -- Get current background
    local function get_dimming_config()
      if vim.o.background == "dark" then
        -- Dark theme: dim to very dark gray
        return {
          alpha = 0.10,  -- 90% dimmed - very obvious
          color = { "Normal", "#1a1a1a" },  -- Dim to almost black
        }
      else
        -- Light theme: dim to light gray
        return {
          alpha = 0.20,  -- 80% dimmed
          color = { "Normal", "#f5f5f5" },  -- Dim to very light gray
        }
      end
    end

    local dimming = get_dimming_config()

      require("twilight").setup({
        dimming = {
          alpha = dimming.alpha,
          color = dimming.color,
          inactive = true,
        },
        context = 15,  -- Show more context
        treesitter = false,
        expand = {
          "function",
          "method",
          "table",
          "if_statement",
        },
      })
    end,
  },
  -- ==========================================================================
  -- FILE EXPLORER
  -- ==========================================================================

  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
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
        ["<C-h>"] = "actions.select_split",
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

  {
    "GCBallesteros/jupytext.nvim",
    ft = { "ipynb" },
    config = function()
      require("jupytext").setup({
        style = "markdown",  -- Convert to markdown format
        output_extension = "md",
        force_ft = "markdown",
      })
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
