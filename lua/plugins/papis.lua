-- ~/.config/nvim/lua/plugins/papis.lua
-- papis.nvim: bibliography manager integration
-- Requires: go-yq (sudo pacman -S go-yq)

return {
  {
    "kkharji/sqlite.lua",
    lazy = true,
  },

  {
    "MunifTanjim/nui.nvim",
    lazy = true,
  },

  {
    "jghauser/papis.nvim",
    dependencies = {
      "kkharji/sqlite.lua",
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "saghen/blink.cmp",
    },
    ft = { "tex", "markdown", "norg", "yaml", "typst" },
    config = function()
      require("papis").setup({
        -- papis.nvim reads dir/info-name/notes-name/opentool from ~/.config/papis/config
        papis_conf_keys = { "info-name", "notes-name", "dir", "opentool" },

        -- Initialize on tex files in addition to the defaults
        init_filetypes = { "tex", "markdown", "norg", "yaml", "typst" },

        -- Use go-yq (mikefarah) not python-yq
        yq_bin = "yq",

        -- Completion via blink.cmp. papis.nvim registers its native "papis"
        -- source into blink (blink.add_source_provider) — listed in the tex
        -- per_filetype sources in lua/config/completion.lua.
        ["completion"] = {
          enable = true,
          provider = "blink",
        },

        -- Use telescope for search
        ["search"] = {
          enable = true,
          provider = "telescope",
        },

        -- Enable at-cursor actions (open file/notes when cursor is on a ref)
        ["at-cursor"] = {
          enable = true,
        },

        -- Leave ask disabled until LLM stack is ready
        ["ask"] = {
          enable = false,
        },
      })
    end,
    keys = {
      { "<leader>pp", "<cmd>Papis search<cr>",                desc = "Search papers (papis)" },
      { "<leader>pf", "<cmd>Papis at-cursor open-file<cr>",  desc = "Open paper file at cursor" },
      { "<leader>pn", "<cmd>Papis at-cursor open-note<cr>",  desc = "Open paper notes" },
      { "<leader>pi", "<cmd>Papis at-cursor show-popup<cr>", desc = "Paper info popup" },
      { "<leader>pe", "<cmd>Papis at-cursor edit<cr>",       desc = "Edit papis entry" },
    },
  },
}
