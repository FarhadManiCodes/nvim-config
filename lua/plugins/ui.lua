-- ~/.config/nvim/lua/plugins/ui.lua
-- Visual chrome: file explorer, statusline, icons, focus dimming.

return {
  -- ==========================================================================
  -- FILE EXPLORER
  -- ==========================================================================

  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    -- Loads eagerly only when nvim starts on a directory or oil:// URL; this
    -- saves ~7 ms (oil + devicons) on every other launch. default_file_explorer
    -- installs its hijack from setup() (oil/init.lua:1403) and netrw is disabled
    -- in config/lazy.lua, so anything that adds a directory buffer before oil
    -- loads would otherwise get an empty, filetype-less buffer. `init` covers
    -- those routes: it loads oil, then replays oil's own handlers, which only
    -- act on the current buffer or on events that already fired. Depends on
    -- oil's "Oil" augroup and its BufAdd/SessionLoadPost handlers; recheck
    -- `:e dir`, `:split dir`, `:tabe dir` and a restored session after updating.
    lazy = not (vim.fn.argc(-1) > 0
      and (vim.fn.isdirectory(vim.fn.argv(0)) == 1 or vim.fn.argv(0):match("^oil[%-%w]*://") ~= nil)),
    cmd = "Oil",
    init = function()
      local group = vim.api.nvim_create_augroup("OilLazyDirHijack", { clear = true })
      vim.api.nvim_create_autocmd("BufAdd", {
        group = group,
        callback = function(a)
          if vim.fn.isdirectory(a.file) == 1 or a.file:match("^oil[%-%w]*://") then
            require("lazy").load({ plugins = { "oil.nvim" } })
            -- Setup only hijacks the current buffer; :split/:tabe add theirs first.
            vim.api.nvim_exec_autocmds("BufAdd", { group = "Oil", buffer = a.buf })
            return true -- oil is loaded now; drop this trigger
          end
        end,
      })
      -- Restored sessions name oil buffers via :file, which fires no BufAdd.
      vim.api.nvim_create_autocmd("SessionLoadPost", {
        group = group,
        callback = function()
          for _, b in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_get_name(b):match("^oil[%-%w]*://") then
              require("lazy").load({ plugins = { "oil.nvim" } })
              vim.api.nvim_exec_autocmds("SessionLoadPost", { group = "Oil", buffer = b })
            end
          end
        end,
      })
    end,
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

      -- Use supported Oil actions; the previous aliases are deprecated.
      keymaps = {
        ["g?"] = "actions.show_help",
        ["<CR>"] = "actions.select",
        ["<C-s>"] = { "actions.select", opts = { vertical = true } },
        -- <C-x>, not oil's default <C-h>: <C-h/j/k/l> are vim-tmux-navigator's
        -- split/pane movement everywhere else, and a buffer-local map wins over
        -- a global one, so oil was the single place those four keys did not
        -- navigate. Trade-off: <C-x> otherwise falls through to the built-in
        -- decrement-number, which is now unavailable while renaming in oil.
        ["<C-x>"] = { "actions.select", opts = { horizontal = true } },
        -- Explicit false is REQUIRED to drop oil's default: this table is
        -- merged into oil's defaults, not substituted for them, so simply
        -- omitting <C-h> leaves oil's own binding in place (see :h oil-config,
        -- "Set to `false` to remove a keymap").
        ["<C-h>"] = false,
        ["<C-t>"] = { "actions.select", opts = { tab = true } },
        ["<C-p>"] = "actions.preview",
        ["<C-c>"] = "actions.close",
        ["<C-r>"] = "actions.refresh",
        ["-"] = "actions.parent",
        ["_"] = "actions.open_cwd",
        ["`"] = "actions.cd",
        ["~"] = { "actions.cd", opts = { scope = "tab" } },
        ["gs"] = "actions.change_sort",
        ["gx"] = "actions.open_external",
        ["g."] = "actions.toggle_hidden",
        ["g\\"] = "actions.toggle_trash",
        -- yank_entry, not copy_entry_path: same yank, but it appends "/" for a
        -- directory and takes an `opts.modify` fnamemodify argument.
        ["gy"] = "actions.yank_entry",  -- Copy file path!
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
}
