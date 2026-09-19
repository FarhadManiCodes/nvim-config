-- ~/.config/nvim/lua/plugins/ui.lua
-- Visual chrome: file explorer, statusline, icons, focus dimming.

return {
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
