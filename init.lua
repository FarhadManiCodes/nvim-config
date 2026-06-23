-- ~/.config/nvim/init.lua
-- Neovim 0.11+ configuration entry point
-- This file orchestrates the loading of all configuration modules

-- =============================================================================
-- PHASE 1: BOOTSTRAP - Set fundamental variables that everything else depends on
-- =============================================================================

-- Enable bytecode cache for faster startup (Neovim 0.11+)
vim.loader.enable()

-- Set leader key BEFORE any plugins or keymaps load
-- Leader key is used for custom keybindings (e.g., <leader>th for theme toggle)
vim.g.mapleader = "\\"  -- Backslash (Vim default, explicit)

-- Load API keys from ~/.config/secrets/*.env into this process's env (see
-- lua/config/secrets.lua). Done in Lua, not sourced by zsh, so the value is
-- present however nvim was launched and never leaks into the shell environment.
-- No-op until the placeholder key is filled in. Consumed via os.getenv (minuet).
require("config.secrets").load("codestral.env")

-- =============================================================================
-- PHASE 2: CORE CONFIGURATION - Load editor behavior and plugin infrastructure
-- =============================================================================

-- Load editor options (behavior, appearance, etc.)
require("config.options")

-- Bootstrap lazy.nvim and load all plugins
-- This also handles theme loading after plugins are ready
require("config.lazy")

-- Load LSP configuration (after plugins, before UI)
-- Configures clangd (C/C++), basedpyright (Python), bashls (Bash)
require("config.lsp")

-- =============================================================================
-- PHASE 3: USER INTERFACE - Load behaviors that respond to events and actions
-- =============================================================================

-- Load autocommands (file type detection, large file handling, etc.)
require("config.autocmds")

-- Load keybindings (after plugins are loaded)
require("config.keymaps")

-- =============================================================================
-- CONFIGURATION COMPLETE
-- =============================================================================
-- Plugins load on-demand based on their configuration in lua/plugins/init.lua
-- Theme is restored from last session (handled in config/lazy.lua)
-- All keymaps and autocommands are now active
