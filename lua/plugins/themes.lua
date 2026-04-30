-- ~/.config/nvim/lua/plugins/themes.lua

return {
  {
    "navarasu/onedark.nvim",
    name = "onedark",
    priority = 1001,  -- Higher priority than newpaper (loads first)
    lazy = false,
    config = function()
      local themes = require("config.themes")
      require("onedark").setup(themes.onedark_config)
      -- Note: Actual colorscheme application handled in lazy.lua (theme persistence)
    end,
  },

  {
    "yorik1984/newpaper.nvim",
    name = "newpaper",
    priority = 1000,
    lazy = true,
    config = function()
      local themes = require("config.themes")
      require("newpaper").setup(themes.newpaper_config)
    end,
  },
}
