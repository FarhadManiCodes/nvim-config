-- ~/.config/nvim/lua/plugins/treesitter.lua
-- Treesitter setup for Neovim 0.12+ using nvim-treesitter main branch.
--
-- Why this setup exists:
--   nvim-treesitter master branch is archived and incompatible with Neovim 0.12.
--   The main branch is a full rewrite: no configs.setup(), lazy=false required,
--   parsers installed via require('nvim-treesitter').install({}).
--
-- Critical: Neovim 0.12 bundles a few parsers (lua, c, markdown, etc.) but those
--   bundled versions are older than the queries nvim-treesitter main ships with.
--   ALL parsers — including the bundled ones — must be re-installed via nvim-treesitter
--   so that parser versions match query files. nvim-treesitter prepends its install_dir
--   to runtimepath, so its parsers take precedence over Neovim's bundled ones.

return {
  -- ==========================================================================
  -- TREESITTER: Parser management, queries, and injections
  -- ==========================================================================

  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,   -- main branch does NOT support lazy loading
    build = ":TSUpdate",

    config = function()
      require("nvim-treesitter").setup({})

      -- Install/update all parsers we care about, including ones bundled with
      -- Neovim (lua, c, markdown, etc.) so they stay in sync with the queries.
      require("nvim-treesitter").install({
        -- Bundled with Neovim 0.12 but must be overridden to match main's queries
        "lua", "c", "vim", "vimdoc", "query",
        "markdown", "markdown_inline",

        -- HPC / CFD
        "cpp",

        -- Data engineering / scientific
        "python", "sql", "scala",

        -- Systems
        "go", "rust",

        -- Scripting
        "bash",

        -- Web / dashboards
        "javascript", "typescript", "tsx", "html", "css",

        -- Config / data formats
        "yaml", "json", "toml",

        -- Documentation
        "latex",

        -- Build / infrastructure
        "dockerfile", "cmake", "make",

        -- Version control
        "git_config", "git_rebase", "gitcommit", "gitignore", "diff",

        -- Meta
        "regex",
      })

      -- Enable treesitter highlighting for every filetype with an available parser.
      -- Neovim 0.12's ftplugin already calls vim.treesitter.start() for bundled
      -- languages (lua, c, markdown…), so this autocmd mainly covers the rest.
      -- Guards: skip buffers flagged large (>10 MB by autocmds.lua) or >1 MB.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("treesitter_start", { clear = true }),
        callback = function(args)
          if vim.b[args.buf].large_file then return end
          local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(args.buf))
          if ok and stats and stats.size > 1024 * 1024 then return end
          pcall(vim.treesitter.start, args.buf)  -- silent: no parser = no error
        end,
      })
    end,
  },

  -- ==========================================================================
  -- TREESITTER TEXTOBJECTS: af/if, ac/ic, aa/ia, ]m/[m navigation
  -- ==========================================================================

  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    event = { "BufReadPost", "BufNewFile" },

    config = function()
      require("nvim-treesitter-textobjects").setup({
        select = { lookahead = true },
        move   = { set_jumps = true },
      })

      local sel = require("nvim-treesitter-textobjects.select")
      local mov = require("nvim-treesitter-textobjects.move")

      -- ── Text object selections (visual + operator-pending) ───────────────
      local select_maps = {
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        ["ac"] = "@class.outer",
        ["ic"] = "@class.inner",
        ["aa"] = "@parameter.outer",
        ["ia"] = "@parameter.inner",
        ["ab"] = "@block.outer",
        ["ib"] = "@block.inner",
        ["al"] = "@loop.outer",
        ["il"] = "@loop.inner",
        ["ai"] = "@conditional.outer",
        ["ii"] = "@conditional.inner",
        ["a/"] = "@comment.outer",
      }
      for lhs, capture in pairs(select_maps) do
        vim.keymap.set({ "x", "o" }, lhs, function()
          sel.select_textobject(capture, "textobjects")
        end, { desc = "Select " .. capture })
      end

      -- ── Motion navigation ────────────────────────────────────────────────
      vim.keymap.set({ "n", "x", "o" }, "]m",  function() mov.goto_next_start("@function.outer",    "textobjects") end, { desc = "Next function start" })
      vim.keymap.set({ "n", "x", "o" }, "]M",  function() mov.goto_next_start("@class.outer",       "textobjects") end, { desc = "Next class start"    })
      vim.keymap.set({ "n", "x", "o" }, "]me", function() mov.goto_next_end("@function.outer",      "textobjects") end, { desc = "Next function end"   })
      vim.keymap.set({ "n", "x", "o" }, "]Me", function() mov.goto_next_end("@class.outer",         "textobjects") end, { desc = "Next class end"      })
      vim.keymap.set({ "n", "x", "o" }, "[m",  function() mov.goto_previous_start("@function.outer","textobjects") end, { desc = "Prev function start" })
      vim.keymap.set({ "n", "x", "o" }, "[M",  function() mov.goto_previous_start("@class.outer",   "textobjects") end, { desc = "Prev class start"    })
      vim.keymap.set({ "n", "x", "o" }, "[me", function() mov.goto_previous_end("@function.outer",  "textobjects") end, { desc = "Prev function end"   })
      vim.keymap.set({ "n", "x", "o" }, "[Me", function() mov.goto_previous_end("@class.outer",     "textobjects") end, { desc = "Prev class end"      })
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
      enable            = false,
      max_lines         = 3,
      min_window_height = 20,
      line_numbers      = true,
      multiline_threshold = 1,
      trim_scope        = "outer",
      mode              = "cursor",
      separator         = nil,
    },
  },
}
