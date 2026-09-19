-- ~/.config/nvim/lsp/lua_ls.lua
-- LUA_LS (THIS CONFIG ITSELF)
-- This config is written in Lua and previously had no Lua server, so vim.api
-- completion, diagnostics and goto-definition were missing for it.
-- Installation: sudo pacman -S lua-language-server  (official extra repo)

return {
  cmd = { "lua-language-server" },

  filetypes = { "lua" },

  -- .luarc.json first so a project can override; lazy-lock.json identifies a
  -- Neovim config root specifically, which .git alone would not.
  root_markers = { ".luarc.json", ".luarc.jsonc", "lazy-lock.json", ".git" },

  settings = {
    Lua = {
      runtime = {
        -- Neovim embeds LuaJIT, not PUC Lua 5.4. Wrong value here means the
        -- server offers 5.4-only stdlib and flags LuaJIT builtins.
        version = "LuaJIT",
      },
      diagnostics = {
        -- Without this every single `vim.` is reported as an undefined global,
        -- which is loud enough to make the server worse than none.
        globals = { "vim" },
      },
      workspace = {
        -- Neovim's own Lua, so vim.api/vim.fn/vim.uv resolve. Deliberately NOT
        -- the whole plugin tree: indexing ~40 plugins to make require("oil")
        -- resolve costs far more than it returns. lazydev.nvim is the tool for
        -- that if it ever becomes worth it.
        library = { vim.env.VIMRUNTIME .. "/lua" },
        -- Stops the "this workspace uses luassert, configure it?" prompts.
        checkThirdParty = false,
      },
      telemetry = { enable = false },
      format = {
        -- Leaves <leader>cf working on Lua, which had no formatter before.
        -- *.lua is intentionally absent from the format-on-save glob in lua/config/lsp.lua:
        -- reformatting this repo wholesale on every save would bury real
        -- diffs, so Lua formatting stays manual.
        enable = true,
      },
    },
  },
}
