-- ~/.config/nvim/lua/plugins/minuet.lua
-- minuet-ai.nvim: manual, on-demand AI code completion (Codestral via FIM).
--
-- Design (see docs/ai-completion.md):
--   * Cloud-only Codestral — true FIM endpoint, EU/GDPR, ~€2-6/mo manual (free tier exists).
--   * minuet's OWN virtual-text frontend (NOT a blink source): multi-line ghost text is the
--     right UI for FIM, and keeping it off blink's fast path means a cloud request fires
--     ONLY when you ask (manual), never as you type.
--   * Insert-mode → Alt keymaps (<leader> is normal-mode; vimtex owns <leader>ll).
--   * API key: loaded by lua/config/secrets.lua from ~/.config/secrets/codestral.env into
--     vim.env, so os.getenv("CODESTRAL_API_KEY") resolves here. Nothing secret in the repo.
--
-- No dependencies: minuet uses builtin vim.system (needs Neovim 0.10+; we're 0.11+).

return {
  "milanglacier/minuet-ai.nvim",
  event = "InsertEnter",
  config = function()
    require("minuet").setup({
      provider = "codestral",
      n_completions = 1,        -- default 3; one suggestion = low-noise
      context_window = 16000,   -- max context chars sent (default)
      request_timeout = 3,      -- seconds; raise if cloud completions truncate

      provider_options = {
        codestral = {
          model = "codestral-latest",
          end_point = "https://codestral.mistral.ai/v1/fim/completions",
          api_key = "CODESTRAL_API_KEY", -- env-var NAME (set by config.secrets)
          stream = true,
          optional = {
            max_tokens = 256,   -- caps output; prevents timeouts on long gens
            stop = { "\n\n" },
          },
        },
      },

      virtualtext = {
        auto_trigger_ft = {},   -- MANUAL only: no auto-suggest on any filetype
        -- prev/next double as the manual INVOKE when no suggestion is showing,
        -- then cycle candidates once one is visible.
        keymap = {
          accept         = "<A-A>", -- accept whole completion
          accept_line    = "<A-a>", -- accept one line
          accept_n_lines = "<A-z>", -- accept N lines (prompts for a count)
          prev           = "<A-[>", -- invoke / cycle previous
          next           = "<A-]>", -- invoke / cycle next
          dismiss        = "<A-e>",
        },
        -- show_on_completion_menu defaults to false → AI ghost text and the blink
        -- menu stay out of each other's way.
      },
    })
  end,
}
