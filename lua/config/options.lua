-- ~/.config/nvim/lua/config/options.lua
-- Modern Neovim 0.11+ option configuration
-- Optimized for data engineering workflow - December 2025

-- =============================================================================
-- PERFORMANCE: NEOVIM 0.11 SPECIFIC OPTIMIZATIONS
-- =============================================================================

local opt = vim.opt  -- Convenient shorthand
local g = vim.g      -- Global variables

-- =============================================================================
-- EDITOR BEHAVIOR: FUNDAMENTAL SETTINGS
-- =============================================================================

-- File handling
opt.autoread = true             -- Reload files changed outside of vim
opt.confirm = true              -- Confirm before closing unsaved buffers
-- Backup and swap files
-- Philosophy: With persistent undo and git, these are less necessary
opt.swapfile = false
opt.backup = false
opt.writebackup = false

-- Persistent undo (CRITICAL!)
-- Neovim 0.11 automatically creates parent directories
local undodir = vim.fn.stdpath("data") .. "/undodir"
opt.undofile = true
opt.undodir = undodir
opt.undolevels = 10000
opt.undoreload = 3000           -- Lines to trigger undo save on reload (reduced from 10000)


-- =============================================================================
-- VISUAL APPEARANCE: NUMBERS AND SIGNS
-- =============================================================================

-- Line numbers
opt.number = true               -- Show line numbers
opt.relativenumber = true       -- Show relative line numbers (used for motions)

-- Sign column (where git signs, LSP diagnostics appear)
opt.signcolumn = "yes"          -- Always show to prevent text shifting

-- Cursor and scrolling
opt.cursorline = true           -- Highlight current line
opt.scrolloff = 6               -- Keep 6 lines visible above/below cursor
opt.sidescrolloff = 8           -- Keep 8 columns visible left/right

-- =============================================================================
-- INDENTATION: GLOBAL DEFAULTS
-- =============================================================================

opt.expandtab = true            -- Use spaces instead of tabs
opt.tabstop = 4                 -- Tab display width (Python standard)
opt.shiftwidth = 4              -- Indentation width for << and >>
opt.softtabstop = 4             -- Tab width when editing
opt.smartindent = true          -- Context-aware auto-indent

-- Note: File-type specific indentation (YAML=2, Go=tabs) will be
-- configured in autocmds.lua

-- =============================================================================
-- SEARCH: INTELLIGENT DEFAULTS
-- =============================================================================

opt.hlsearch = true             -- Highlight search results
opt.incsearch = true            -- Incremental search (show matches as you type)
opt.ignorecase = true           -- Case-insensitive search...
opt.smartcase = true            -- ...unless search contains uppercase

-- Note: Use <leader><space> to clear search highlighting (defined in keymaps.lua)

-- =============================================================================
-- WINDOW SPLITS: MODERN BEHAVIOR
-- =============================================================================

opt.splitright = true           -- New vertical splits go right
opt.splitbelow = true           -- New horizontal splits go below

-- Matches modern IDE and tmux behavior

-- =============================================================================
-- COMMAND LINE AND COMPLETION
-- =============================================================================

opt.wildmenu = true             -- Enhanced command-line completion
opt.wildmode = "longest:full,full"
opt.wildoptions = "pum"         -- Use popup menu for completion (Neovim 0.11+)

-- =============================================================================
-- CLIPBOARD INTEGRATION
-- =============================================================================

opt.clipboard = ""              -- Don't sync with system clipboard automatically
-- Use "+y / "+p explicitly for system clipboard
-- Prevents dd (delete) from polluting system clipboard!

-- Clipboard provider: wl-copy locally, OSC 52 over SSH
-- OSC 52 carries clipboard data through the terminal (works through tmux + SSH)
if vim.env.SSH_TTY ~= nil then
  -- Over SSH: wl-copy unavailable, use OSC 52 through terminal
  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
      ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
    },
    paste = {
      ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
      ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
    },
  }
  -- else: let neovim auto-detect wl-copy/wl-paste (already works locally)
end

-- =============================================================================
-- TIMING AND RESPONSIVENESS
-- =============================================================================

opt.updatetime = 250            -- Faster CursorHold events, gitsigns refresh
opt.timeoutlen = 600            -- Time to wait for next key in sequence (comfortable pace)
opt.ttimeoutlen = 10            -- Fast terminal key code timeout

-- =============================================================================
-- DISPLAY AND RENDERING
-- =============================================================================

opt.termguicolors = true        -- Enable 24-bit RGB colors
vim.o.winborder = "rounded"     -- Global rounded borders for all floating windows

-- Popup menu configuration
opt.pumheight = 15              -- Max items in completion menu
opt.pumblend = 0                -- Popup transparency (0 = opaque, readable)

-- Line wrapping
opt.wrap = true                 -- Wrap long lines
opt.linebreak = true            -- Wrap at word boundaries, not mid-word
opt.breakindent = true          -- Wrapped lines maintain indent

-- =============================================================================
-- MESSAGES AND FEEDBACK
-- =============================================================================

opt.showcmd = false             -- Don't show partial commands (prefer clean interface)
opt.showmode = false            -- Don't show mode (cursor shape indicates mode)

-- Customize message behavior
opt.shortmess:append({
  I = true,  -- No intro message on startup
  W = true,  -- Don't show "written" when saving
  c = true,  -- Don't show ins-completion-menu messages
  C = true,  -- Don't show scanning message for ins-completion
})

-- =============================================================================
-- FOLDING: TREESITTER-BASED
-- =============================================================================

opt.foldcolumn = "1"            -- Show fold indicator column (useful visual feedback)
opt.foldlevel = 99              -- Open most folds by default
opt.foldlevelstart = 99         -- Start with all folds open
opt.foldenable = true           -- Enable folding
opt.foldmethod = "expr"         -- Use expression for folding (Treesitter)
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"  -- Neovim 0.11+ native treesitter folding
opt.foldnestmax = 10            -- Maximum fold depth
-- Uses Neovim's built-in treesitter folding (0.11+)
-- Faster and more reliable than the old nvim_treesitter#foldexpr()

-- =============================================================================
-- DIFF SETTINGS: Modern algorithms for better diffs
-- =============================================================================

opt.diffopt = {
  "internal",           -- Use Neovim's built-in diff library (faster than external diff)
  "filler",             -- Show filler lines to keep text aligned in diffs
  "closeoff",           -- Turn off diff mode when one window closes
  "context:5",          -- Show 5 lines of context around changes (cleaner than default 6)
  "algorithm:histogram",-- Superior to 'myers' algorithm for code diffs
  "indent-heuristic",   -- Better alignment for indentation changes (critical for Python/YAML)
  "linematch:60",       -- Highlight word-level changes within lines (game changer!)
  "inline:char",        -- Character-level highlighting within a changed line (Nvim 0.12+)
}
-- Why histogram? The default 'myers' algorithm minimizes line changes but gets confused
-- by braces and indentation. Histogram keeps logical code blocks together.
-- Why linematch? Shows exactly which words changed in a line, not just "line changed"
-- Why inline:char? Without it, 'diffopt' falls back to "inline:simple" (highlights the
-- whole span from first to last differing character). "char" runs an actual char-wise
-- diff within the line instead, so only the changed characters are highlighted.
-- Perfect for: Python (indent-heuristic), YAML (dbt/DVC), C++ (histogram)

-- Make deleted lines use diagonal pattern instead of dashes (clearer visual)
opt.fillchars:append({ diff = "╱" })

-- These settings benefit:
-- - gitsigns.nvim hunk previews (better diff display)
-- - :diffsplit and :DiffThis (comparing files)
-- - Merge conflict resolution
-- - Any diff view in Neovim

-- =============================================================================
-- MOUSE SUPPORT
-- =============================================================================

opt.mouse = "a"                 -- Enable mouse in all modes
opt.mousemoveevent = true       -- Enable hover events (Neovim 0.11+)

-- Even if not actively used, enables:
-- - LSP hover documentation (when LSP is added)
-- - Quick scrolling when needed
-- - Presentations/demos (easier to show)

-- =============================================================================
-- COMPLETION EXPERIENCE (LSP-optimized)
-- =============================================================================

opt.completeopt = {
  "menu",       -- Show completion menu
  "menuone",    -- Show menu even if only one match
  "noselect",   -- Don't auto-select first item (you choose what to insert)
}

-- =============================================================================
-- FORMAT OPTIONS
-- =============================================================================

-- Control auto-formatting behavior
opt.formatoptions:remove({ "c", "r", "o" })
-- Removed:
-- c: Don't auto-wrap comments
-- r: Don't auto-insert comment leader after <Enter> in insert mode
-- o: Don't auto-insert comment leader after 'o' or 'O' in normal mode

opt.formatoptions:append({ "n", "j" })
-- Added:
-- n: Recognize numbered lists when formatting (useful in markdown)
-- j: Remove comment leader when joining lines with J

-- =============================================================================
-- CURSOR CONFIGURATION
-- =============================================================================

-- Neovim's guicursor provides fine-grained control over cursor appearance
-- This is why you don't need "-- INSERT --" at the bottom - the cursor tells you!
opt.guicursor = {
  "n-v-c:block",              -- Normal, Visual, Command: block cursor
  "i-ci-ve:ver25",            -- Insert: thin vertical bar (25% width)
  "r-cr:hor20",               -- Replace: thin horizontal bar (20% height)
  "o:hor50",                  -- Operator-pending: medium horizontal bar
  "a:blinkwait700-blinkoff400-blinkon250",  -- Blink settings for all modes
  "sm:block-blinkwait175-blinkoff150-blinkon175",  -- Showmatch: fast blink
}

-- =============================================================================
-- SYNTAX AND RENDERING
-- =============================================================================

-- Performance optimizations for syntax highlighting
opt.synmaxcol = 300            -- Don't highlight lines longer than 300 chars
                                -- Prevents lag on very long lines (minified code, wide CSVs)

opt.redrawtime = 1500          -- Max time for syntax highlighting (ms)
                                -- Prevents freezing on complex syntax

-- =============================================================================
-- WHITESPACE VISIBILITY
-- =============================================================================

opt.list = true                 -- Show whitespace characters
opt.listchars = {
  tab = "→ ",                   -- Show tabs as arrow + space
  trail = "·",                  -- Show trailing spaces as middle dot
  nbsp = "␣",                   -- Show non-breaking spaces
  extends = "⟩",                -- Show when line continues right (nowrap)
  precedes = "⟨",               -- Show when line continues left (nowrap)
}
-- Helpful for: YAML indentation, CSV alignment, Python whitespace debugging
-- If too noisy, disable with: opt.list = false

-- =============================================================================
-- TERMINAL TITLE
-- =============================================================================

opt.title = true                -- Set terminal/tmux title to filename
opt.titlestring = "NVIM - %t"   -- "NVIM - filename"
-- Useful in tmux: see which file is open in each pane

-- =============================================================================
-- SPELL CHECKING
-- =============================================================================

opt.spell = false               -- Disabled by default
opt.spelllang = "en_us"         -- Language (when enabled)
-- Will be enabled per-filetype in autocmds.lua for .tex files

-- =============================================================================
-- SHELL CONFIGURATION
-- =============================================================================

-- Use zsh if available, fallback to bash
if vim.fn.executable("zsh") == 1 then
  opt.shell = "zsh"
else
  opt.shell = "bash"
end

-- This affects:
-- - :!command execution
-- - :terminal shell
-- - Shell script execution

-- =============================================================================
-- PROVIDERS (Neovim external program integration)
-- =============================================================================

-- Disable providers we don't need (performance optimization)
g.loaded_ruby_provider = 0     -- No Ruby plugins
g.loaded_perl_provider = 0     -- No Perl plugins (ancient)
g.loaded_node_provider = 0     -- No Node.js plugins
g.loaded_python3_provider = 0  -- No Python provider (using LSP instead)

-- =============================================================================
-- PROJECT-LOCAL CONFIG
-- =============================================================================

-- Auto-load .nvim.lua, trusted via :trust. Nvim 0.12+ also searches parent
-- directories (not just cwd) for the file, so on shared/mounted filesystems
-- a trust prompt can surface from a .nvim.lua higher up the tree than expected.
opt.exrc = true

-- =============================================================================
-- END OF OPTIONS
-- =============================================================================

-- Note: File-type specific settings (indentation, etc.) are in autocmds.lua
-- Note: Keybindings are in keymaps.lua
-- Note: Plugin configurations are in plugins/init.lua
