-- ~/.config/nvim/lsp/yamlls.lua
-- YAML LANGUAGE SERVER (DATA ENGINEERING - dbt, CI, docker-compose)
-- Schema-aware completion + validation via SchemaStore.
-- Installation: sudo pacman -S yaml-language-server  (official extra repo)

return {
  cmd = { "yaml-language-server", "--stdio" },

  filetypes = { "yaml" },

  root_markers = { ".git" },

  settings = {
    yaml = {
      schemaStore = {
        enable = true,        -- pull schemas from SchemaStore.org
        url = "https://www.schemastore.org/api/json/catalog.json",
      },
      validate = true,
      keyOrdering = false,    -- don't complain about key order
    },
    redhat = { telemetry = { enabled = false } },
  },
}
