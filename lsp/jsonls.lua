-- ~/.config/nvim/lsp/jsonls.lua
-- JSON LANGUAGE SERVER (DATA ENGINEERING - configs, package.json)
-- Installation: sudo pacman -S vscode-json-languageserver  (official extra repo)

return {
  cmd = { "vscode-json-languageserver", "--stdio" },

  filetypes = { "json", "jsonc" },

  root_markers = { ".git" },

  settings = {
    json = {
      schemaStore = { enable = true },
      validate = { enable = true },
    },
  },
}
