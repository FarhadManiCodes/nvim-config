-- ~/.config/nvim/lua/config/themes.lua

local M = {}

-- Onedark configuration
M.onedark_config = {
  style = "dark",
  transparent = false,
  term_colors = true,
  ending_tildes = false,
  cmp_itemkind_reverse = false,

  code_style = {
    comments = 'italic',
    keywords = 'none',
    functions = 'none',
    strings = 'none',
    variables = 'none'
  },

  lualine = {
    transparent = false,
  },

  highlights = {
    -- Custom highlight overrides
    Normal = { bg = "#282c34", fg = "#abb2bf" },
    Folded = { fg = "#282c34", bg = "#4b5263" },
    FoldColumn = { fg = "#4b5263", bg = "NONE" },
    Comment = { fg = "#5c6370", italic = true },
    SignColumn = { bg = "NONE" },
    LineNr = { fg = "#4b5263" },
    CursorLineNr = { fg = "#abb2bf", bold = true },
    Visual = { bg = "#3e4452" },
    Search = { bg = "#528bff", fg = "#282c34" },
    IncSearch = { bg = "#98c379", fg = "#282c34" },
    Pmenu = { bg = "#2c323c" },
    PmenuSel = { bg = "#3e4452" },
    NormalFloat = { bg = "#2c323c" },
    FloatBorder = { fg = "#4b5263", bg = "#2c323c" },
    DiagnosticError = { fg = "#e06c75" },
    DiagnosticWarn = { fg = "#e5c07b" },
    DiagnosticInfo = { fg = "#61afef" },
    DiagnosticHint = { fg = "#98c379" },
    DiffAdd = { bg = "#2c5a2e" },
    DiffChange = { bg = "#1e3a5f" },
    DiffDelete = { fg = "#e06c75", bg = "#4a2730" },
    DiffText = { bg = "#2e5077" },
  },

  diagnostics = {
    darker = true,
    undercurl = true,
    background = true,
  },
}

-- Newpaper configuration
M.newpaper_config = {
  style = "light",

  custom_highlights = {
    Normal = { bg = "#eeeeee", fg = "#444444" },
    NormalFloat = { bg = "#d9d9d9", fg = "#444444" },
    Comment = { fg = "#008700", italic = true },
    LineNr = { fg = "#b2b2b2", bg = "NONE" },
    CursorLineNr = { fg = "#005f87", bg = "#e4e4e4", bold = true },
    CursorLine = { bg = "#e4e4e4" },
    SignColumn = { bg = "NONE" },
    FoldColumn = { fg = "#b2b2b2", bg = "NONE" },
    Visual = { bg = "#d0d0d0" },
    Search = { bg = "#ffff5f", fg = "#000000" },
    IncSearch = { bg = "#5fafff", fg = "#000000" },
    Folded = { fg = "#666666", bg = "#d0d0d0" },
    StatusLine = { fg = "#444444", bg = "#d0d0d0" },
    StatusLineNC = { fg = "#666666", bg = "#e4e4e4" },
    Pmenu = { bg = "#d9d9d9", fg = "#444444" },
    PmenuSel = { bg = "#5fafff", fg = "#ffffff" },
    PmenuSbar = { bg = "#d0d0d0" },
    PmenuThumb = { bg = "#808080" },
    FloatBorder = { fg = "#808080", bg = "#d9d9d9" },
    DiagnosticError = { fg = "#af0000" },
    DiagnosticWarn = { fg = "#d75f00" },
    DiagnosticInfo = { fg = "#0087af" },
    DiagnosticHint = { fg = "#008700" },
    DiffAdd = { bg = "#d7ffd7", fg = "NONE" },
    DiffChange = { bg = "#d7d7ff", fg = "NONE" },
    DiffDelete = { bg = "#ffd7d7", fg = "#af0000" },
    DiffText = { bg = "#afafff", fg = "NONE" },
  },
}

-- =============================================================================
-- THEME REGISTRY — the single source of truth for which themes exist
-- =============================================================================
-- Adding a theme used to mean editing three files that each hardcoded the
-- names (this one, plugins/themes.lua, and the restore guard in config/lazy.lua).
-- The name list now lives here and config/lazy.lua reads M.is_valid(), so a new
-- entry here plus its plugin spec is all that is needed.
--
--   background — 'background' is asserted both before and after :colorscheme;
--                some colorschemes set it themselves and would otherwise flip it.
--   modules    — purged from package.loaded before setup() so a re-apply picks
--                up config changes instead of reusing the cached module.
M.themes = {
  onedark = {
    background = "dark",
    config = M.onedark_config,
    modules = { "onedark", "onedark.colors", "onedark.highlights", "onedark.util" },
    label = "→ Dark theme",
  },
  newpaper = {
    background = "light",
    config = M.newpaper_config,
    modules = { "newpaper", "newpaper.theme" },
    label = "→ Light theme",
  },
}

function M.is_valid(name)
  return name ~= nil and M.themes[name] ~= nil
end

-- Apply a registered theme by name. Replaces the former apply_onedark /
-- apply_newpaper pair, which were identical apart from the three values now
-- held in the registry above.
function M.apply(name)
  local theme = M.themes[name]
  if not theme then
    vim.notify("Unknown theme: " .. tostring(name), vim.log.levels.ERROR)
    return false
  end

  vim.opt.background = theme.background
  for _, mod in ipairs(theme.modules) do
    package.loaded[mod] = nil
  end
  require(name).setup(theme.config)
  vim.cmd.colorscheme(name)
  vim.opt.background = theme.background

  return true
end

-- Filename shared with the restore in config/lazy.lua.
M.STATE_FILE = "last_theme.txt"

-- Save current theme preference
local function save_theme(theme_name)
  require("config.state").write(M.STATE_FILE, theme_name)
end

-- Toggle between light and dark
function M.toggle()
  local target = vim.g.colors_name == "onedark" and "newpaper" or "onedark"
  if M.apply(target) then
    save_theme(target)
    vim.notify(M.themes[target].label, vim.log.levels.INFO)
  end
end

return M
