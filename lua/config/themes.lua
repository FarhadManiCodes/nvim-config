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

-- Apply onedark theme
function M.apply_onedark()
  -- Force background to dark BEFORE loading theme
  vim.opt.background = "dark"

  -- Clear onedark modules from cache
  package.loaded['onedark'] = nil
  package.loaded['onedark.colors'] = nil
  package.loaded['onedark.highlights'] = nil
  package.loaded['onedark.util'] = nil

  -- Setup and apply
  require("onedark").setup(M.onedark_config)
  vim.cmd([[colorscheme onedark]])

  -- Force background again after applying (double-ensure)
  vim.opt.background = "dark"
end

-- Apply newpaper theme
function M.apply_newpaper()
  -- Force background to light BEFORE loading theme
  vim.opt.background = "light"

  -- Clear newpaper modules from cache
  package.loaded['newpaper'] = nil
  package.loaded['newpaper.theme'] = nil

  -- Setup and apply
  require("newpaper").setup(M.newpaper_config)
  vim.cmd([[colorscheme newpaper]])

  -- Force background again after applying
  vim.opt.background = "light"
end

-- Save current theme preference
local function save_theme(theme_name)
  local theme_file = vim.fn.stdpath("data") .. "/last_theme.txt"
  local file = io.open(theme_file, "w")
  if file then
    file:write(theme_name)
    file:close()
  end
end

-- Toggle between themes
function M.toggle()
  if vim.g.colors_name == "onedark" then
    M.apply_newpaper()
    save_theme("newpaper")
    vim.notify("→ Light theme", vim.log.levels.INFO)
  else
    M.apply_onedark()
    save_theme("onedark")
    vim.notify("→ Dark theme", vim.log.levels.INFO)
  end
end

return M
