-- ~/.config/nvim/lua/plugins/data-tools.lua
-- Data-engineering specific plugins: database queries, CSV handling, env vars.

return {
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
      -- $DATABASE_URL, g:db (:h dadbod). The local server holds one database,
      -- `postgres`, and its password is a podman secret, so the working path is
      -- to export DATABASE_URL from that secret in the shell that launches nvim
      -- and set nothing here. See docs/architecture.md, "Database Configuration".
      -- Never hardcode credentials.
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
}
