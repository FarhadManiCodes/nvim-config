-- ~/.config/nvim/lua/plugins/treesitter.lua
-- Treesitter setup for Neovim 0.12+ using nvim-treesitter main branch.
--
-- Why this setup exists:
--   nvim-treesitter's frozen master branch targets Neovim 0.11.
--   The main branch is a full rewrite: no configs.setup(), lazy=false required,
--   parsers installed via require('nvim-treesitter').install({}).
--
-- Manage even Neovim's bundled languages here: their bundled parser versions
-- need not match this plugin's queries. Its install_dir is prepended to
-- runtimepath, giving the managed parsers priority over the bundled copies.

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

      -- Asynchronously install missing parsers; install() skips installed ones.
      -- Updates use :TSUpdate via the build hook and config/autocmds.lua.
      --
      -- Keep this list complete: a parser that is installed but NOT named here
      -- works on this machine and vanishes on a fresh one, with no error --
      -- highlighting just quietly stops. asm, ini, kdl and bibtex were all in
      -- that state until the 2026-08 audit. (One more, zathurarc, is an orphan:
      -- upstream no longer lists that parser, so the standard installer cannot
      -- restore it if the old copy inside the plugin clone is removed.
      -- Decided 2026-09-20: let it go. It survives only inside the plugin clone
      -- and highlights one 682-byte config edited about twice a year, so it is
      -- not worth hand-restoring a grammar its authors deleted. When it goes,
      -- ~/.config/zathura/zathurarc opens as plain text and nothing else
      -- changes -- zathura is kept for DjVu; sioyek is the PDF viewer.)
      require("nvim-treesitter").install({
        -- Bundled languages, managed here to match this plugin's queries
        "lua", "c", "vim", "vimdoc", "query",
        "markdown", "markdown_inline",

        -- HPC / CFD. asm is for reading compiler output (.s) next to the source
        -- it came from, not for writing assembly.
        "cpp", "asm",

        -- Data engineering / scientific
        "python", "sql", "scala",

        -- Systems
        "go", "rust",

        -- Scripting. zsh has its own grammar and it is what makes ft=zsh
        -- viable: without it `foldexpr` and the textobject queries find no
        -- parser, so folding and ]m/af silently stop working in .zshrc. The
        -- bash parser is NOT a substitute -- it errors on zsh-only syntax such
        -- as `print -l ${(f)arr}`, where the zsh grammar parses cleanly.
        -- Tier 2 (georgeharker/tree-sitter-zsh), so expect the odd rough edge;
        -- the one known here is an emoji inside a `${1:-...}` default.
        "bash", "zsh",

        -- Web / dashboards
        "javascript", "typescript", "tsx", "html", "css",

        -- Config / data formats. ini covers ft=dosini (foot.ini, fuzzel.ini) and
        -- kdl covers niri's config.kdl -- both files edited often enough that
        -- losing their highlighting on a fresh machine would be noticed.
        "yaml", "json", "toml", "ini", "kdl",

        -- Documentation. bibtex covers ft=bib, i.e. the refs.bib that papis-bib
        -- generates and prunes.
        "latex",
        "typst",
        "bibtex",

        -- Build / infrastructure
        "dockerfile", "cmake", "make",

        -- Version control
        "git_config", "git_rebase", "gitcommit", "gitignore", "diff",

        -- Meta
        "regex",
      })

      -- Native ftplugins can start highlighting themselves. Stop it explicitly
      -- above 1 MiB (or with b:large_file), and disable folding in every window
      -- showing the buffer. Track edits, hidden buffers and later window entry.
      require("config.treesitter").setup()
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
      -- Function keys follow Neovim's ]m/[m/]M/[M method-motion convention.
      -- Class keys use section-motion keys. Runtime buffer-local mappings can
      -- override these globals (notably SQL blocks and Markdown headings).
      --   function: start ]m/[m   end ]M/[M
      --   class:    start ]]/[[   end ][/[]
      vim.keymap.set({ "n", "x", "o" }, "]m", function() mov.goto_next_start("@function.outer",     "textobjects") end, { desc = "Next function start" })
      vim.keymap.set({ "n", "x", "o" }, "]M", function() mov.goto_next_end("@function.outer",       "textobjects") end, { desc = "Next function end"   })
      vim.keymap.set({ "n", "x", "o" }, "]]", function() mov.goto_next_start("@class.outer",        "textobjects") end, { desc = "Next class start"    })
      vim.keymap.set({ "n", "x", "o" }, "][", function() mov.goto_next_end("@class.outer",          "textobjects") end, { desc = "Next class end"      })
      vim.keymap.set({ "n", "x", "o" }, "[m", function() mov.goto_previous_start("@function.outer", "textobjects") end, { desc = "Prev function start" })
      vim.keymap.set({ "n", "x", "o" }, "[M", function() mov.goto_previous_end("@function.outer",   "textobjects") end, { desc = "Prev function end"   })
      vim.keymap.set({ "n", "x", "o" }, "[[", function() mov.goto_previous_start("@class.outer",    "textobjects") end, { desc = "Prev class start"    })
      vim.keymap.set({ "n", "x", "o" }, "[]", function() mov.goto_previous_end("@class.outer",      "textobjects") end, { desc = "Prev class end"      })
    end,
  },

  -- ==========================================================================
  -- TREESITTER CONTEXT: Sticky function/class headers
  -- ==========================================================================

  {
    "nvim-treesitter/nvim-treesitter-context",
    dependencies = { "nvim-treesitter/nvim-treesitter" },

    -- The installed plugin exposes :TSContext subcommands and this Lua API;
    -- the former :TSContextToggle command is no longer available.
    keys = {
      { "<leader>tc", function() require("treesitter-context").toggle() end,
        desc = "Toggle treesitter context" },
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
