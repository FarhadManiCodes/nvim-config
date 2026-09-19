-- ~/.config/nvim/lua/plugins/core.lua
-- Fast lookup/insert infrastructure: telescope (fuzzy finding) and blink.cmp
-- (completion). plenary.nvim is declared once, as telescope's dependency.

return {
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
