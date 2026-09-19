-- ~/.config/nvim/lua/plugins/editor.lua
-- Filetype-agnostic editing and workflow enhancements: surround, structural
-- split/join, bracket motions, autopairs, tmux navigation, session tracking,
-- git signs.

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
}
