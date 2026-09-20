-- ~/.config/nvim/lua/plugins/minuet.lua
-- minuet-ai.nvim: manual, on-demand AI code completion (Codestral via FIM).
--
-- Design (see docs/ai-completion.md):
--   * Cloud-only Codestral — FIM endpoint; pricing and provider policy in the guide.
--   * minuet's OWN virtual-text frontend (NOT a blink source): multi-line ghost text is the
--     right UI for FIM, and keeping it off blink's fast path means a cloud request fires
--     ONLY when you ask (manual), never as you type.
--   * Insert-mode Alt keymaps keep AI separate from document and navigation keys.
--   * API key: loaded by lua/config/secrets.lua from ~/.config/secrets/codestral.env into
--     an in-process table. Minuet reads it through a callback, without exporting it.
--
-- No plugin dependencies: minuet uses builtin vim.system and curl; config needs 0.12+.

return {
  "milanglacier/minuet-ai.nvim",
  event = "InsertEnter",
  config = function()
    require("minuet").setup({
      provider = "codestral",
      n_completions = 3,     -- three FIM requests per invocation; cycle with Alt brackets
      request_timeout = 5,   -- seconds; allow slower responses to finish
      -- Keep context_window=16000 and notify="warn" at their defaults.

      provider_options = {
        codestral = {
          model = "codestral-latest",
          end_point = "https://codestral.mistral.ai/v1/fim/completions",
          -- A FUNCTION, not an env-var name: minuet's utils.get_api_key() calls
          -- it and uses the return value. The key is therefore read straight out
          -- of config.secrets' in-process table and never enters vim.env — so
          -- none of the programs nvim spawns (LSP servers, :terminal, :!, jobs)
          -- inherit it, which they would if it lived in the environment.
          api_key = function()
            return require("config.secrets").get("CODESTRAL_API_KEY")
          end,
          stream = true,
          optional = {
            max_tokens = 256,   -- caps output; does not guarantee finishing before timeout
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
