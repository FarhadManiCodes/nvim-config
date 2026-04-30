-- ~/.config/nvim/lua/plugins/treesitter.lua
-- Treesitter: Better syntax highlighting and code understanding

return {
  -- ==========================================================================
  -- TREESITTER: Core Parser and Highlighting
  -- ==========================================================================

  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",  -- Auto-update parsers after installation
    event = { "BufReadPost", "BufNewFile" },  -- Load when opening files

    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",  -- Smart text objects
    },

    config = function()
      require("nvim-treesitter.configs").setup({
        -- ====================================================================
        -- PARSER INSTALLATION
        -- ====================================================================

        ensure_installed = {
          -- Core programming languages
          "python",           -- Data engineering, daily work
          "lua",              -- Neovim configuration
          "c", "cpp",         -- HPC/CFD, Trilinos

          -- JVM/Functional
          "scala",            -- Spark

          -- Systems programming
          "go",               -- CLI tools
          "rust",             -- Occasional use

          -- Scripting
          "bash",             -- Shell scripts

          -- Web development
          "javascript",       -- Dashboards
          "typescript",       -- Web scraping
          "tsx",              -- React TypeScript
          "html",             -- Web
          "css",              -- Styling

          -- Data formats
          "sql",              -- Databases
          "yaml",             -- Configs (dbt, DVC, K8s, Docker Compose)
          "json",             -- Data, configs
          "toml",             -- pyproject.toml, Rust configs

          -- Documentation
          "markdown",         -- READMEs, documentation
          "markdown_inline",  -- Inline markdown parsing
          "latex",            -- LaTeX documents (required for vimtex integration)

          -- Build/Infrastructure
          "dockerfile",       -- Docker
          "cmake",            -- C/C++ builds
          "make",             -- Makefiles

          -- Version control
          "git_config",       -- .gitconfig
          "git_rebase",       -- Interactive rebase
          "gitcommit",        -- Commit messages
          "gitignore",        -- .gitignore files
          "diff",             -- Diff files

          -- Meta (Neovim internals)
          "vim",              -- Vim syntax
          "vimdoc",           -- Neovim help files
          "query",            -- Treesitter queries themselves
          "regex",            -- Regex patterns
        },

        -- Auto-install parsers for unknown languages
        auto_install = true,

        -- Don't block Neovim startup during parser installation
        sync_install = false,

        -- Don't ignore any language parsers
        ignore_install = {},

        -- ====================================================================
        -- SYNTAX HIGHLIGHTING
        -- ====================================================================

        highlight = {
          enable = true,  -- Enable treesitter-based highlighting

          -- Disable highlighting for large files (performance)
          disable = function(lang, buf)
            -- Check 1: Large file flag set by autocmd (10MB threshold)
            if vim.b[buf].large_file then
              return true
            end

            -- Check 2: Treesitter-specific threshold (1MB)
            -- Treesitter parsing is computationally expensive
            local max_filesize = 1000 * 1024  -- 1MB
            local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
            if ok and stats and stats.size > max_filesize then
              return true
            end

            return false
          end,

          -- Use additional Vim regex highlighting for certain languages
          -- vimtex and vim-markdown plugins require traditional syntax for their features
          -- (e.g., vimtex concealment, markdown fenced code blocks)
          additional_vim_regex_highlighting = { "latex", "markdown" },
        },

        -- ====================================================================
        -- SMART INDENTATION
        -- ====================================================================

        indent = {
          enable = true,  -- Use treesitter for indentation

          -- Disable for languages where it causes issues
          -- Uncomment if you experience problems:
          -- disable = { "python", "yaml" },
        },

        -- ====================================================================
        -- INCREMENTAL SELECTION (Expand selection intelligently)
        -- ====================================================================

        incremental_selection = {
          enable = true,
          keymaps = {
            -- Start selection with Ctrl+Space
            init_selection = "<C-Space>",

            -- Expand selection with Ctrl+Space (press repeatedly)
            node_incremental = "<C-Space>",

            -- Shrink selection with Backspace
            node_decremental = "<BS>",

            -- Expand to entire scope (function, class, etc.)
            scope_incremental = "<C-s>",
          },

          -- Note: If <C-Space> doesn't work in your terminal/compositor:
          -- Alternative keymaps: "<CR>" (Enter) or "v" (in visual mode)
        },

        -- ====================================================================
        -- TEXT OBJECTS (Select and manipulate code structures)
        -- ====================================================================

        textobjects = {
          -- Selection text objects
          select = {
            enable = true,

            -- Jump forward to next text object if cursor not inside one
            lookahead = true,

            keymaps = {
              -- Functions
              ["af"] = "@function.outer",  -- Select entire function
              ["if"] = "@function.inner",  -- Select function body

              -- Classes
              ["ac"] = "@class.outer",     -- Select entire class
              ["ic"] = "@class.inner",     -- Select class body

              -- Parameters/Arguments
              ["aa"] = "@parameter.outer", -- Select parameter with comma
              ["ia"] = "@parameter.inner", -- Select parameter only

              -- Code blocks
              ["ab"] = "@block.outer",     -- Select block with braces
              ["ib"] = "@block.inner",     -- Select block content

              -- Loops (for, while)
              ["al"] = "@loop.outer",      -- Select entire loop
              ["il"] = "@loop.inner",      -- Select loop body

              -- Conditionals (if, else)
              ["ai"] = "@conditional.outer", -- Select entire conditional
              ["ii"] = "@conditional.inner", -- Select conditional body

              -- Comments
              ["a/"] = "@comment.outer",   -- Select entire comment block
            },
          },

          -- Navigation between code structures
          move = {
            enable = true,
            set_jumps = true,
            goto_next_start = {
              ["]m"] = "@function.outer",
              ["]M"] = "@class.outer",
            },
            goto_next_end = {
              ["]me"] = "@function.outer",
              ["]Me"] = "@class.outer",
            },
            goto_previous_start = {
              ["[m"] = "@function.outer",
              ["[M"] = "@class.outer",
            },
            goto_previous_end = {
              ["[me"] = "@function.outer",
              ["[Me"] = "@class.outer",
            },
          },
        },
      })

      -- Note: Folding configuration is in options.lua:
      -- vim.opt.foldmethod = "expr"
      -- vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"  -- Neovim 0.11+ native
    end,
  },

  -- ==========================================================================
  -- TREESITTER CONTEXT: Sticky function/class headers
  -- ==========================================================================

  {
    "nvim-treesitter/nvim-treesitter-context",
    dependencies = { "nvim-treesitter/nvim-treesitter" },

    keys = {
      { "<leader>tc", "<cmd>TSContextToggle<cr>", desc = "Toggle treesitter context" },
    },

    opts = {
      enable = false,           -- Start disabled (toggle with <leader>tc)
      max_lines = 3,            -- Show up to 3 context lines
      min_window_height = 20,   -- Don't show in small windows
      line_numbers = true,      -- Show line numbers in context
      multiline_threshold = 1,  -- Show context if more than 1 line
      trim_scope = 'outer',     -- Remove outer whitespace
      mode = 'cursor',          -- Position: 'cursor' or 'topline'
      separator = nil,          -- No separator line (nil, '-', or '━')
    },
  },
}
