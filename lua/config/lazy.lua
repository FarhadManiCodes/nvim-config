-- ~/.config/nvim/lua/config/lazy.lua
-- Official lazy.nvim bootstrap and configuration
-- Based on: https://lazy.folke.io/installation
-- Creates lazy-lock.json for reproducible plugin versions (commit to git!)

-- =============================================================================
-- BOOTSTRAP: Auto-install lazy.nvim if not present
-- =============================================================================

-- Where lazy.nvim will be installed
-- stdpath("data") returns ~/.local/share/nvim on Unix systems
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

-- Check if lazy.nvim exists (Neovim 0.11+)
local uv = vim.uv

if not uv.fs_stat(lazypath) then
  -- Check if git is installed
  if vim.fn.executable("git") == 0 then
    vim.notify("Git is required to bootstrap lazy.nvim", vim.log.levels.ERROR)
    return
  end

  -- lazy.nvim not found, so clone it
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  
  -- Use vim.fn.system to run git clone
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",  -- Partial clone for faster download
    "--branch=stable",     -- Use stable branch, not main
    lazyrepo,
    lazypath,
  })
  
  -- Check if git clone succeeded
  if vim.v.shell_error ~= 0 then
    -- Show error message and exit
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end

-- Add lazy.nvim to the runtime path so we can require it
-- This must happen BEFORE require("lazy")
vim.opt.rtp:prepend(lazypath)

-- =============================================================================
-- LAZY.NVIM CONFIGURATION
-- =============================================================================

require("lazy").setup({
  -- Specification of plugins to load
  -- This tells lazy.nvim to import all plugin specs from lua/plugins/
  spec = {
    -- Import all plugin files from lua/plugins/ directory
    { import = "plugins" },
  },

  -- ==========================================================================
  -- ROCKS: Disable luarocks support (not needed for our plugins)
  -- ==========================================================================
  rocks = {
    enabled = false,  -- Disable luarocks (none of our plugins need it)
  },

  -- ==========================================================================
  -- DEFAULTS: Applied to all plugins unless overridden
  -- ==========================================================================
  defaults = {
    lazy = false,  -- Plugins load at startup by default
    -- Why false? Explicit is better than implicit. We opt-in to lazy loading
    -- per-plugin where it makes sense (event = "VeryLazy", etc.)
    
    version = false,  -- Don't version-lock plugins
    -- Why false? We want latest features. If stability is critical for
    -- a specific plugin, we'll version-lock that one individually.
  },

  -- ==========================================================================
  -- INSTALLATION: How lazy.nvim installs plugins
  -- ==========================================================================
  install = {
    -- If a colorscheme is missing, use these as fallbacks
    colorscheme = { "onedark", "habamax" },
    -- habamax is a Neovim built-in, so it's always available as last resort
  },

  -- ==========================================================================
  -- CHECKER: Automatic update checking
  -- ==========================================================================
  checker = {
    enabled = true,      -- Check for plugin updates
    notify = false,      -- Don't spam notifications
    frequency = 86400,   -- Check once per day (24 hours)
    -- This runs in the background. When updates are available,
    -- you'll see a count in the lazy.nvim UI (:Lazy)
  },

  -- ==========================================================================
  -- CHANGE DETECTION: Auto-reload on config changes
  -- ==========================================================================
  change_detection = {
    enabled = true,   -- Watch for config file changes
    notify = false,   -- Silently reload (no popup spam)
  },
  -- When you save a plugin config file, lazy.nvim detects it and
  -- automatically reloads. No manual :source needed.

  -- ==========================================================================
  -- UI: Customize the lazy.nvim interface
  -- ==========================================================================
  ui = {
    size = { width = 0.8, height = 0.8 },  -- 80% of screen
    wrap = true,  -- Wrap long lines in UI
    border = "rounded",  -- Rounded border (Neovim 0.11 renders beautifully)
    title = "Plugin Manager",
    title_pos = "center",
    -- Use lazy.nvim's default icons (clean, well-designed)
  },

  -- ==========================================================================
  -- PERFORMANCE: Critical optimizations
  -- ==========================================================================
  performance = {
    cache = {
      enabled = true,
      -- lazy.nvim caches plugin metadata to speed up subsequent startups
      -- This is separate from vim.loader bytecode caching
    },
    
    reset_packpath = true,  -- Reset packpath to improve startup time
    
    rtp = {
      reset = true,  -- Reset runtime path to improve startup time
      
      -- Paths to add to runtimepath (in addition to lazy.nvim's managed plugins)
      -- This is where you'd add custom paths if needed
      -- paths = {},
      
      -- Disable built-in Vim plugins that we don't need
      -- Each one saved is a few milliseconds of startup time
      disabled_plugins = {
        "gzip",
        "matchit",
        -- matchparen kept enabled - shows matching brackets when cursor is on them
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },

  -- ==========================================================================
  -- PROFILING: Performance analysis (disabled by default)
  -- ==========================================================================
  -- Uncomment to enable startup profiling
  -- profiling = {
  --   loader = true,
  --   require = true,
  -- },
  -- When enabled, :Lazy profile shows detailed startup timing
})

-- =============================================================================
-- THEME LOADING - Restore last used theme
-- =============================================================================
-- This runs after lazy.setup() completes, so colorscheme plugins are loaded

local themes = require("config.themes")

-- The desktop light/dark state wins at startup, so Neovim matches the terminal
-- it opens in; <leader>th then overrides for the session only. Same contract as
-- vim, which picks its colorscheme from this state file at VimEnter. Without it
-- a light terminal running a dark colorscheme bleeds light-tuned highlight
-- backgrounds through dark text.
--
-- last_theme.txt remains the fallback for when the desktop state is missing --
-- a bare tty, or before the toggle has ever run.
local pick = themes.from_desktop()

if not themes.is_valid(pick) then
  local saved = require("config.state").read(themes.STATE_FILE)
  -- Validate against the registry in config/themes.lua rather than a hardcoded
  -- name list, so adding a theme does not require editing this file too.
  pick = themes.is_valid(saved) and saved or "onedark"
end

vim.cmd.colorscheme(pick)

-- =============================================================================
-- LAZY.NVIM MANAGEMENT
-- =============================================================================
-- No keymaps - use :Lazy command to open UI
-- The UI has single-key shortcuts:
--   U - Update all plugins
--   S - Sync (clean + update)
--   C - Clean unused plugins
--   I - Install missing plugins
--   P - Show profile
--   ? - Show help
